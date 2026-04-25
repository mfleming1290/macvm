import CoreVideo
import LiveKitWebRTC
import XCTest
@testable import MacAgent

final class CapturePixelFormatTests: XCTestCase {
    func testWebRTCCVPixelBufferSupportsVideoRangeNV12() {
        let supportedFormats = LKRTCCVPixelBuffer.supportedPixelFormats()
        XCTAssertTrue(
            supportedFormats.contains(NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)),
            "LiveKitWebRTC must support video-range NV12 CVPixelBuffers before ScreenCaptureKit captures that format."
        )
    }

    func testCaptureRuntimeSettingsDefaultToSafeNV12() {
        let settings = CaptureRuntimeSettings.current(environment: [:])

        XCTAssertEqual(settings.pixelFormat, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        XCTAssertEqual(settings.pixelFormatName, "420v")
        XCTAssertEqual(settings.queueDepth, 2)
    }

    func testCaptureRuntimeSettingsAllowBGRAFallback() {
        let settings = CaptureRuntimeSettings.current(
            environment: ["MACVM_CAPTURE_PIXEL_FORMAT": "bgra"]
        )

        XCTAssertEqual(settings.pixelFormat, kCVPixelFormatType_32BGRA)
        XCTAssertEqual(settings.pixelFormatName, "BGRA")
    }

    func testCaptureRuntimeSettingsAllowSupportedQueueDepthOverrides() {
        XCTAssertEqual(
            CaptureRuntimeSettings.current(environment: ["MACVM_SCK_QUEUE_DEPTH": "1"]).queueDepth,
            1
        )
        XCTAssertEqual(
            CaptureRuntimeSettings.current(environment: ["MACVM_SCK_QUEUE_DEPTH": "2"]).queueDepth,
            2
        )
        XCTAssertEqual(
            CaptureRuntimeSettings.current(environment: ["MACVM_SCK_QUEUE_DEPTH": "3"]).queueDepth,
            3
        )
    }

    func testCaptureRuntimeSettingsRejectUnsupportedQueueDepthOverrides() {
        XCTAssertEqual(
            CaptureRuntimeSettings.current(environment: ["MACVM_SCK_QUEUE_DEPTH": "0"]).queueDepth,
            2
        )
        XCTAssertEqual(
            CaptureRuntimeSettings.current(environment: ["MACVM_SCK_QUEUE_DEPTH": "4"]).queueDepth,
            2
        )
        XCTAssertEqual(
            CaptureRuntimeSettings.current(environment: ["MACVM_SCK_QUEUE_DEPTH": "slow"]).queueDepth,
            2
        )
    }
}
