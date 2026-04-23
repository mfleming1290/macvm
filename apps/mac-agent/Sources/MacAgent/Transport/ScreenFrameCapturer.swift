import CoreMedia
import Foundation
import LiveKitWebRTC

final class ScreenFrameCapturer: LKRTCVideoCapturer {
    private let deliveryQueue = DispatchQueue(label: "macvm.capture.delivery")
    private let diagnosticsLock = NSLock()
    private var droppedBackpressureFrames = 0
    private var deliveredFrames = 0
    private var isDelivering = false
    private var lastTimestampNs: Int64?
    private var pendingSampleBuffer: CMSampleBuffer?
    private var sourceFrames = 0

    var diagnostics: MediaDiagnostics {
        diagnosticsLock.lock()
        defer { diagnosticsLock.unlock() }

        var diagnostics = MediaDiagnostics.empty
        diagnostics.droppedBackpressureFrames = droppedBackpressureFrames
        diagnostics.capturerFrames = deliveredFrames
        diagnostics.sourceFrames = sourceFrames
        diagnostics.lastTimestampNs = lastTimestampNs
        return diagnostics
    }

    func capture(sampleBuffer: CMSampleBuffer) {
        let sampleBuffer = sampleBuffer
        deliveryQueue.async { [weak self] in
            self?.enqueue(sampleBuffer: sampleBuffer)
        }
    }

    private func enqueue(sampleBuffer: CMSampleBuffer) {
        diagnosticsLock.lock()
        sourceFrames += 1

        guard !isDelivering else {
            if pendingSampleBuffer != nil {
                droppedBackpressureFrames += 1
            }
            pendingSampleBuffer = sampleBuffer
            diagnosticsLock.unlock()
            return
        }

        isDelivering = true
        diagnosticsLock.unlock()
        deliver(sampleBuffer: sampleBuffer)
    }

    private func deliver(sampleBuffer: CMSampleBuffer) {
        var nextSampleBuffer: CMSampleBuffer? = sampleBuffer

        while let currentSampleBuffer = nextSampleBuffer {
            autoreleasepool {
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(currentSampleBuffer) else {
                    return
                }

                let timestampNs = frameTimestampNs(for: currentSampleBuffer)
                let buffer = LKRTCCVPixelBuffer(pixelBuffer: pixelBuffer)
                let frame = LKRTCVideoFrame(buffer: buffer, rotation: ._0, timeStampNs: timestampNs)
                delegate?.capturer(self, didCapture: frame)

                diagnosticsLock.lock()
                deliveredFrames += 1
                lastTimestampNs = timestampNs
                diagnosticsLock.unlock()
            }

            diagnosticsLock.lock()
            nextSampleBuffer = pendingSampleBuffer
            pendingSampleBuffer = nil
            if nextSampleBuffer == nil {
                isDelivering = false
            }
            diagnosticsLock.unlock()
        }
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
