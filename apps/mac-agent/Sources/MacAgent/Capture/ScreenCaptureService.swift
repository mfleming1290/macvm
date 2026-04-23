import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

final class ScreenCaptureService: NSObject, SCStreamOutput {
    var onFrame: ((CMSampleBuffer) -> Void)?

    private let outputQueue = DispatchQueue(label: "macvm.capture.output")
    private var stream: SCStream?

    func start() async throws {
        if stream != nil {
            return
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first else {
            throw CaptureError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = true

        let nextStream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try nextStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        try await nextStream.startCapture()
        stream = nextStream
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
        guard outputType == .screen, sampleBuffer.isValid else {
            return
        }

        onFrame?(sampleBuffer)
    }
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
