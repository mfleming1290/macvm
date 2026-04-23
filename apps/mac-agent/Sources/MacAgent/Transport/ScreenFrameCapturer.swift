import CoreMedia
import Foundation
import LiveKitWebRTC

final class ScreenFrameCapturer: LKRTCVideoCapturer {
    func capture(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampNs = Int64(CMTimeGetSeconds(timestamp) * 1_000_000_000)
        let buffer = LKRTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let frame = LKRTCVideoFrame(buffer: buffer, rotation: ._0, timeStampNs: timestampNs)
        delegate?.capturer(self, didCapture: frame)
    }
}
