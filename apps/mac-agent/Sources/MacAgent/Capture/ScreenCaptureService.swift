import CoreMedia
import CoreVideo
import CoreGraphics
import Foundation
import ScreenCaptureKit

final class ScreenCaptureService: NSObject, SCStreamOutput {
    var onFrame: ((CMSampleBuffer) -> Void)?

    private let diagnosticsLock = NSLock()
    private let outputQueue = DispatchQueue(label: "macvm.capture.output")
    private var captureFrames = 0
    private var completeFrames = 0
    private var droppedFrames = 0
    private var currentDisplayFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
    private var lastFrameWidth: Int?
    private var lastFrameHeight: Int?
    private var lastPixelFormat: String?
    private var selectedStreamMaxLongEdge: Int?
    private var sourceDisplayHeight: Int?
    private var sourceDisplayWidth: Int?
    private var stream: SCStream?
    private var targetHeight = 0
    private var targetWidth = 0

    var diagnostics: MediaDiagnostics {
        diagnosticsLock.lock()
        defer { diagnosticsLock.unlock() }

        var diagnostics = MediaDiagnostics.empty
        diagnostics.captureFrames = captureFrames
        diagnostics.completeFrames = completeFrames
        diagnostics.droppedFrames = droppedFrames
        diagnostics.lastFrameWidth = lastFrameWidth
        diagnostics.lastFrameHeight = lastFrameHeight
        diagnostics.lastPixelFormat = lastPixelFormat
        diagnostics.sourceDisplayWidth = sourceDisplayWidth
        diagnostics.sourceDisplayHeight = sourceDisplayHeight
        diagnostics.selectedStreamMaxLongEdge = selectedStreamMaxLongEdge
        return diagnostics
    }

    func start(streamSettings: StreamQualitySettings = .defaultSettings) async throws -> CaptureConfiguration {
        if stream != nil {
            return CaptureConfiguration(
                width: targetWidth,
                height: targetHeight,
                framesPerSecond: 30,
                displayFrame: currentDisplayFrame,
                sourceDisplayWidth: sourceDisplayWidth ?? targetWidth,
                sourceDisplayHeight: sourceDisplayHeight ?? targetHeight,
                selectedStreamMaxLongEdge: selectedStreamMaxLongEdge,
                selectedBitrateBps: streamSettings.safeMaxBitrateBps
            )
        }

        resetDiagnostics()

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first else {
            throw CaptureError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        let captureSize = scaledCaptureSize(
            width: display.width,
            height: display.height,
            maxLongEdge: streamSettings.maxLongEdge
        )
        configuration.width = captureSize.width
        configuration.height = captureSize.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = true

        let nextStream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try nextStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        try await nextStream.startCapture()
        stream = nextStream
        targetWidth = captureSize.width
        targetHeight = captureSize.height
        currentDisplayFrame = CGDisplayBounds(CGDirectDisplayID(display.displayID))
        sourceDisplayWidth = display.width
        sourceDisplayHeight = display.height
        selectedStreamMaxLongEdge = streamSettings.maxLongEdge

        return CaptureConfiguration(
            width: captureSize.width,
            height: captureSize.height,
            framesPerSecond: 30,
            displayFrame: currentDisplayFrame,
            sourceDisplayWidth: display.width,
            sourceDisplayHeight: display.height,
            selectedStreamMaxLongEdge: streamSettings.maxLongEdge,
            selectedBitrateBps: streamSettings.safeMaxBitrateBps
        )
    }

    func stop() async {
        guard let stream else {
            return
        }

        try? await stream.stopCapture()
        self.stream = nil
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen else {
            return
        }

        recordReceivedFrame(sampleBuffer)

        guard sampleBuffer.isValid, isCompleteFrame(sampleBuffer) else {
            recordDroppedFrame()
            return
        }

        recordCompleteFrame(sampleBuffer)
        onFrame?(sampleBuffer)
    }

    private func isCompleteFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer,
                createIfNecessary: false
            ) as? [[SCStreamFrameInfo: Any]],
            let statusRaw = attachments.first?[SCStreamFrameInfo.status] as? Int,
            let status = SCFrameStatus(rawValue: statusRaw)
        else {
            return true
        }

        return status == .complete
    }

    private func recordReceivedFrame(_ sampleBuffer: CMSampleBuffer) {
        diagnosticsLock.lock()
        defer { diagnosticsLock.unlock() }
        captureFrames += 1

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        lastFrameWidth = CVPixelBufferGetWidth(pixelBuffer)
        lastFrameHeight = CVPixelBufferGetHeight(pixelBuffer)
        lastPixelFormat = pixelFormatName(CVPixelBufferGetPixelFormatType(pixelBuffer))
    }

    private func recordCompleteFrame(_ sampleBuffer: CMSampleBuffer) {
        diagnosticsLock.lock()
        completeFrames += 1
        diagnosticsLock.unlock()
    }

    private func recordDroppedFrame() {
        diagnosticsLock.lock()
        droppedFrames += 1
        diagnosticsLock.unlock()
    }

    private func resetDiagnostics() {
        diagnosticsLock.lock()
        captureFrames = 0
        completeFrames = 0
        droppedFrames = 0
        lastFrameWidth = nil
        lastFrameHeight = nil
        lastPixelFormat = nil
        sourceDisplayWidth = nil
        sourceDisplayHeight = nil
        selectedStreamMaxLongEdge = nil
        diagnosticsLock.unlock()
    }

    private func scaledCaptureSize(width: Int, height: Int, maxLongEdge: Int?) -> (width: Int, height: Int) {
        guard let maxLongEdge else {
            return (width, height)
        }

        let longEdge = max(width, height)
        guard longEdge > maxLongEdge else {
            return (width, height)
        }

        let scale = Double(maxLongEdge) / Double(longEdge)
        let scaledWidth = max(2, Int((Double(width) * scale).rounded()))
        let scaledHeight = max(2, Int((Double(height) * scale).rounded()))
        return (makeEven(scaledWidth), makeEven(scaledHeight))
    }

    private func makeEven(_ value: Int) -> Int {
        value.isMultiple(of: 2) ? value : value + 1
    }

    private func pixelFormatName(_ pixelFormat: OSType) -> String {
        let bytes = [
            UInt8((pixelFormat >> 24) & 0xff),
            UInt8((pixelFormat >> 16) & 0xff),
            UInt8((pixelFormat >> 8) & 0xff),
            UInt8(pixelFormat & 0xff)
        ]

        if let string = String(bytes: bytes, encoding: .macOSRoman), string.allSatisfy({ !$0.isWhitespace }) {
            return string
        }

        return "\(pixelFormat)"
    }
}

struct CaptureConfiguration {
    let width: Int
    let height: Int
    let framesPerSecond: Int
    let displayFrame: CGRect
    let sourceDisplayWidth: Int
    let sourceDisplayHeight: Int
    let selectedStreamMaxLongEdge: Int?
    let selectedBitrateBps: Int
}

enum CaptureError: LocalizedError {
    case noDisplayAvailable

    var errorDescription: String? {
        switch self {
        case .noDisplayAvailable:
            "No capturable display is available."
        }
    }
}
