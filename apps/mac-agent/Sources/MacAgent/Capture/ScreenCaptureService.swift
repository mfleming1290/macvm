import CoreMedia
import CoreVideo
import CoreGraphics
import Foundation
import ScreenCaptureKit

struct CaptureRuntimeSettings {
    let pixelFormat: OSType
    let pixelFormatName: String
    let queueDepth: Int

    static let defaultPixelFormatName = "420v"
    static let defaultQueueDepth = 2

    static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> CaptureRuntimeSettings {
        let pixelFormatName = normalizedPixelFormatName(environment["MACVM_CAPTURE_PIXEL_FORMAT"])
        return CaptureRuntimeSettings(
            pixelFormat: pixelFormat(for: pixelFormatName),
            pixelFormatName: pixelFormatName,
            queueDepth: normalizedQueueDepth(environment["MACVM_SCK_QUEUE_DEPTH"])
        )
    }

    private static func normalizedPixelFormatName(_ value: String?) -> String {
        switch value?.lowercased() {
        case "bgra":
            return "BGRA"
        default:
            return defaultPixelFormatName
        }
    }

    private static func pixelFormat(for name: String) -> OSType {
        switch name {
        case "BGRA":
            return kCVPixelFormatType_32BGRA
        default:
            return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        }
    }

    private static func normalizedQueueDepth(_ value: String?) -> Int {
        guard let value, let queueDepth = Int(value), (1...3).contains(queueDepth) else {
            return defaultQueueDepth
        }

        return queueDepth
    }
}

final class ScreenCaptureService: NSObject, SCStreamOutput {
    var onFrame: ((CMSampleBuffer) -> Void)?

    private let diagnosticsLock = NSLock()
    private let outputQueue = DispatchQueue(label: "macvm.capture.output")
    private var captureFrames = 0
    private var completeFrames = 0
    private var configuredPixelFormat = CaptureRuntimeSettings.defaultPixelFormatName
    private var configuredQueueDepth = CaptureRuntimeSettings.defaultQueueDepth
    private var configuredStreamFramesPerSecond = StreamQualitySettings.defaultSettings.safeFramesPerSecond
    private var submittedFrames = 0
    private var droppedFrames = 0
    private var droppedIncompleteFrames = 0
    private var droppedPacingFrames = 0
    private var currentDisplayFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
    private var effectiveFramesPerSecond = StreamQualitySettings.defaultSettings.safeFramesPerSecond
    private var lastFrameWidth: Int?
    private var lastFrameHeight: Int?
    private var lastPixelFormat: String?
    private var lastObservedBackpressureFrames = 0
    private var requestedFramesPerSecond = StreamQualitySettings.defaultSettings.safeFramesPerSecond
    private var latestClientStats: StreamClientStats?
    private var submissionGate = FrameSubmissionGate(targetFramesPerSecond: StreamQualitySettings.defaultSettings.safeFramesPerSecond)
    private var selectedStreamMaxLongEdge: Int?
    private var sourceDisplayHeight: Int?
    private var sourceDisplayWidth: Int?
    private var stream: SCStream?
    private var streamConfiguration: SCStreamConfiguration?
    private var targetHeight = 0
    private var targetWidth = 0

    var diagnostics: MediaDiagnostics {
        diagnosticsLock.lock()
        defer { diagnosticsLock.unlock() }

        var diagnostics = MediaDiagnostics.empty
        diagnostics.captureFrames = captureFrames
        diagnostics.completeFrames = completeFrames
        diagnostics.submittedFrames = submittedFrames
        diagnostics.droppedFrames = droppedFrames
        diagnostics.droppedIncompleteFrames = droppedIncompleteFrames
        diagnostics.droppedPacingFrames = droppedPacingFrames
        diagnostics.configuredPixelFormat = configuredPixelFormat
        diagnostics.configuredQueueDepth = configuredQueueDepth
        diagnostics.targetFramesPerSecond = effectiveFramesPerSecond
        diagnostics.requestedFramesPerSecond = requestedFramesPerSecond
        diagnostics.effectiveFramesPerSecond = effectiveFramesPerSecond
        diagnostics.lastFrameWidth = lastFrameWidth
        diagnostics.lastFrameHeight = lastFrameHeight
        diagnostics.lastPixelFormat = lastPixelFormat
        diagnostics.sourceDisplayWidth = sourceDisplayWidth
        diagnostics.sourceDisplayHeight = sourceDisplayHeight
        diagnostics.selectedStreamMaxLongEdge = selectedStreamMaxLongEdge
        diagnostics.clientDecodedFrames = latestClientStats?.decodedFrames
        diagnostics.clientDroppedFrames = latestClientStats?.droppedFrames
        diagnostics.clientEstimatedFramesPerSecond = latestClientStats?.estimatedFramesPerSecond
        diagnostics.clientFrameWidth = latestClientStats?.frameWidth
        diagnostics.clientFrameHeight = latestClientStats?.frameHeight
        diagnostics.clientJitterMs = latestClientStats?.jitterMs
        diagnostics.clientRoundTripTimeMs = latestClientStats?.roundTripTimeMs
        diagnostics.clientBitrateBps = latestClientStats?.bitrateBps
        return diagnostics
    }

    func start(streamSettings: StreamQualitySettings = .defaultSettings) async throws -> CaptureConfiguration {
        if stream != nil {
            return CaptureConfiguration(
                width: targetWidth,
                height: targetHeight,
                framesPerSecond: requestedFramesPerSecond,
                displayFrame: currentDisplayFrame,
                sourceDisplayWidth: sourceDisplayWidth ?? targetWidth,
                sourceDisplayHeight: sourceDisplayHeight ?? targetHeight,
                selectedStreamMaxLongEdge: selectedStreamMaxLongEdge,
                selectedBitrateBps: streamSettings.safeMaxBitrateBps
            )
        }

        resetDiagnostics()
        requestedFramesPerSecond = streamSettings.safeFramesPerSecond
        effectiveFramesPerSecond = streamSettings.safeFramesPerSecond
        submissionGate.updateTargetFramesPerSecond(streamSettings.safeFramesPerSecond)

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first else {
            throw CaptureError.noDisplayAvailable
        }

        let runtimeSettings = CaptureRuntimeSettings.current()
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        let captureSize = scaledCaptureSize(
            width: display.width,
            height: display.height,
            maxLongEdge: streamSettings.maxLongEdge
        )
        configuration.width = captureSize.width
        configuration.height = captureSize.height
        configuration.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(requestedFramesPerSecond)
        )
        configuration.pixelFormat = runtimeSettings.pixelFormat
        configuration.queueDepth = runtimeSettings.queueDepth
        configuration.showsCursor = true

        let nextStream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try nextStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        try await nextStream.startCapture()
        stream = nextStream
        streamConfiguration = configuration
        configuredPixelFormat = runtimeSettings.pixelFormatName
        configuredQueueDepth = runtimeSettings.queueDepth
        configuredStreamFramesPerSecond = requestedFramesPerSecond
        targetWidth = captureSize.width
        targetHeight = captureSize.height
        currentDisplayFrame = CGDisplayBounds(CGDirectDisplayID(display.displayID))
        sourceDisplayWidth = display.width
        sourceDisplayHeight = display.height
        selectedStreamMaxLongEdge = streamSettings.maxLongEdge

        return CaptureConfiguration(
            width: captureSize.width,
            height: captureSize.height,
            framesPerSecond: requestedFramesPerSecond,
            displayFrame: currentDisplayFrame,
            sourceDisplayWidth: display.width,
            sourceDisplayHeight: display.height,
            selectedStreamMaxLongEdge: streamSettings.maxLongEdge,
            selectedBitrateBps: streamSettings.safeMaxBitrateBps
        )
    }

    func updateStreamQuality(_ streamSettings: StreamQualitySettings) {
        diagnosticsLock.lock()
        requestedFramesPerSecond = streamSettings.safeFramesPerSecond
        recomputeEffectiveFramesPerSecondLocked()
        let update = pendingStreamConfigurationUpdateLocked()
        diagnosticsLock.unlock()
        applyStreamConfigurationUpdate(update)
    }

    func applyClientStats(_ stats: StreamClientStats, localDroppedBackpressureFrames: Int) {
        diagnosticsLock.lock()
        latestClientStats = stats
        let backpressureDelta = max(0, localDroppedBackpressureFrames - lastObservedBackpressureFrames)
        lastObservedBackpressureFrames = localDroppedBackpressureFrames
        recomputeEffectiveFramesPerSecondLocked(backpressureDelta: backpressureDelta)
        let update = pendingStreamConfigurationUpdateLocked()
        diagnosticsLock.unlock()
        applyStreamConfigurationUpdate(update)
    }

    func stop() async {
        guard let stream else {
            return
        }

        try? await stream.stopCapture()
        self.stream = nil
        streamConfiguration = nil
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
            recordIncompleteDrop()
            return
        }

        recordCompleteFrame()
        guard shouldSubmitFrame(sampleBuffer) else {
            recordPacingDrop()
            return
        }

        recordSubmittedFrame()
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

    private func recordCompleteFrame() {
        diagnosticsLock.lock()
        completeFrames += 1
        diagnosticsLock.unlock()
    }

    private func recordIncompleteDrop() {
        diagnosticsLock.lock()
        droppedFrames += 1
        droppedIncompleteFrames += 1
        diagnosticsLock.unlock()
    }

    private func recordPacingDrop() {
        diagnosticsLock.lock()
        droppedFrames += 1
        droppedPacingFrames += 1
        diagnosticsLock.unlock()
    }

    private func recordSubmittedFrame() {
        diagnosticsLock.lock()
        submittedFrames += 1
        diagnosticsLock.unlock()
    }

    private func resetDiagnostics() {
        diagnosticsLock.lock()
        captureFrames = 0
        completeFrames = 0
        submittedFrames = 0
        droppedFrames = 0
        droppedIncompleteFrames = 0
        droppedPacingFrames = 0
        configuredPixelFormat = CaptureRuntimeSettings.defaultPixelFormatName
        configuredQueueDepth = CaptureRuntimeSettings.defaultQueueDepth
        configuredStreamFramesPerSecond = StreamQualitySettings.defaultSettings.safeFramesPerSecond
        requestedFramesPerSecond = StreamQualitySettings.defaultSettings.safeFramesPerSecond
        effectiveFramesPerSecond = StreamQualitySettings.defaultSettings.safeFramesPerSecond
        lastFrameWidth = nil
        lastFrameHeight = nil
        lastPixelFormat = nil
        lastObservedBackpressureFrames = 0
        latestClientStats = nil
        submissionGate.reset()
        submissionGate.updateTargetFramesPerSecond(StreamQualitySettings.defaultSettings.safeFramesPerSecond)
        sourceDisplayWidth = nil
        sourceDisplayHeight = nil
        selectedStreamMaxLongEdge = nil
        diagnosticsLock.unlock()
    }

    private func pendingStreamConfigurationUpdateLocked() -> (stream: SCStream, configuration: SCStreamConfiguration, framesPerSecond: Int)? {
        guard
            effectiveFramesPerSecond != configuredStreamFramesPerSecond,
            let stream,
            let streamConfiguration
        else {
            return nil
        }

        streamConfiguration.minimumFrameInterval = CMTime(
            value: 1,
            timescale: CMTimeScale(effectiveFramesPerSecond)
        )
        configuredStreamFramesPerSecond = effectiveFramesPerSecond
        return (stream, streamConfiguration, effectiveFramesPerSecond)
    }

    private func applyStreamConfigurationUpdate(_ update: (stream: SCStream, configuration: SCStreamConfiguration, framesPerSecond: Int)?) {
        guard let update else {
            return
        }

        Task {
            do {
                try await update.stream.updateConfiguration(update.configuration)
                print("macvm media: updated ScreenCaptureKit minimum frame interval to \(update.framesPerSecond) fps")
            } catch {
                print("macvm media: failed to update ScreenCaptureKit frame interval: \(error.localizedDescription)")
            }
        }
    }

    private func shouldSubmitFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        let timestampNs = sampleTimestampNs(for: sampleBuffer)

        diagnosticsLock.lock()
        let shouldSubmit = submissionGate.shouldSubmit(timestampNs: timestampNs)
        diagnosticsLock.unlock()
        return shouldSubmit
    }

    private func sampleTimestampNs(for sampleBuffer: CMSampleBuffer) -> Int64 {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if timestamp.isValid, !timestamp.isIndefinite {
            let seconds = CMTimeGetSeconds(timestamp)
            if seconds.isFinite, seconds >= 0 {
                return Int64(seconds * 1_000_000_000)
            }
        }

        return Int64(DispatchTime.now().uptimeNanoseconds)
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

    private func recomputeEffectiveFramesPerSecondLocked(backpressureDelta: Int = 0) {
        var nextEffectiveFramesPerSecond = requestedFramesPerSecond

        if requestedFramesPerSecond >= 60 {
            if backpressureDelta > 1 ||
                (latestClientStats?.estimatedFramesPerSecond ?? Double(requestedFramesPerSecond)) < 42 ||
                (latestClientStats?.roundTripTimeMs ?? 0) > 120 ||
                (latestClientStats?.jitterMs ?? 0) > 35 {
                nextEffectiveFramesPerSecond = 45
            }

            if backpressureDelta > 4 ||
                (latestClientStats?.estimatedFramesPerSecond ?? Double(requestedFramesPerSecond)) < 28 ||
                (latestClientStats?.droppedFrames ?? 0) > 8 {
                nextEffectiveFramesPerSecond = 30
            }
        } else if requestedFramesPerSecond >= 45 {
            if backpressureDelta > 2 ||
                (latestClientStats?.estimatedFramesPerSecond ?? Double(requestedFramesPerSecond)) < 30 ||
                (latestClientStats?.roundTripTimeMs ?? 0) > 150 ||
                (latestClientStats?.jitterMs ?? 0) > 45 {
                nextEffectiveFramesPerSecond = 30
            }
        }

        guard nextEffectiveFramesPerSecond != effectiveFramesPerSecond else {
            return
        }

        effectiveFramesPerSecond = nextEffectiveFramesPerSecond
        submissionGate.updateTargetFramesPerSecond(nextEffectiveFramesPerSecond)
        print("macvm media: adjusted effective fps to \(nextEffectiveFramesPerSecond) (requested \(requestedFramesPerSecond))")
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
