import CoreMedia
import Foundation
import LiveKitWebRTC

final class ScreenFrameCapturer: LKRTCVideoCapturer {
    private let diagnosticsLock = NSLock()
    private var deliveredFrames = 0
    private var lastTimestampNs: Int64?

    var diagnostics: MediaDiagnostics {
        diagnosticsLock.lock()
        defer { diagnosticsLock.unlock() }

        var diagnostics = MediaDiagnostics.empty
        diagnostics.capturerFrames = deliveredFrames
        diagnostics.sourceFrames = deliveredFrames
        diagnostics.lastTimestampNs = lastTimestampNs
        return diagnostics
    }

    func capture(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let timestampNs = frameTimestampNs(for: sampleBuffer)
        let buffer = LKRTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let frame = LKRTCVideoFrame(buffer: buffer, rotation: ._0, timeStampNs: timestampNs)
        delegate?.capturer(self, didCapture: frame)

        diagnosticsLock.lock()
        deliveredFrames += 1
        lastTimestampNs = timestampNs
        diagnosticsLock.unlock()
    }

    private func frameTimestampNs(for sampleBuffer: CMSampleBuffer) -> Int64 {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if timestamp.isValid, !timestamp.isIndefinite {
            let seconds = CMTimeGetSeconds(timestamp)
            if seconds.isFinite, seconds >= 0 {
                return Int64(seconds * 1_000_000_000)
            }
        }

        return Int64(DispatchTime.now().uptimeNanoseconds)
    }
}
