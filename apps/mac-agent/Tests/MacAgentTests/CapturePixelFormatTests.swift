import CoreVideo
import LiveKitWebRTC
import XCTest

final class CapturePixelFormatTests: XCTestCase {
    func testWebRTCCVPixelBufferSupportsVideoRangeNV12() {
        let supportedFormats = LKRTCCVPixelBuffer.supportedPixelFormats()
        XCTAssertTrue(
            supportedFormats.contains(NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)),
            "LiveKitWebRTC must support video-range NV12 CVPixelBuffers before ScreenCaptureKit captures that format."
        )
    }
}
