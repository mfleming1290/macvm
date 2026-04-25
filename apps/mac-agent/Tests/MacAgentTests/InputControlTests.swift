import CoreGraphics
import XCTest
@testable import MacAgent

final class InputControlTests: XCTestCase {
    func testControlProtocolDecodesMouseButtonMessage() throws {
        let data = Data(
            """
            {
              "version": 1,
              "type": "input.mouse.button",
              "sequence": 12,
              "timestampMs": 1234,
              "button": "left",
              "action": "down",
              "x": 0.25,
              "y": 0.75,
              "buttons": ["left"]
            }
            """.utf8
        )

        guard case .mouseButton(let message) = try ControlProtocol.decode(data) else {
            return XCTFail("Expected a mouse button message.")
        }

        XCTAssertEqual(message.button, .left)
        XCTAssertEqual(message.action, .down)
        XCTAssertEqual(message.x, 0.25)
        XCTAssertEqual(message.y, 0.75)
    }

    func testControlProtocolRejectsOutOfRangeCoordinates() {
        let data = Data(
            """
            {
              "version": 1,
              "type": "input.mouse.move",
              "sequence": 1,
              "timestampMs": 1234,
              "x": 1.2,
              "y": 0.5,
              "buttons": []
            }
            """.utf8
        )

        XCTAssertThrowsError(try ControlProtocol.decode(data))
    }

    func testDisplayCoordinateMapperMapsNormalizedPointIntoDisplayFrame() {
        let mapper = DisplayCoordinateMapper()
        mapper.update(
            captureConfiguration: CaptureConfiguration(
                width: 2000,
                height: 1000,
                framesPerSecond: 30,
                displayFrame: CGRect(x: 100, y: 200, width: 2000, height: 1000),
                sourceDisplayWidth: 2000,
                sourceDisplayHeight: 1000,
                selectedStreamMaxLongEdge: 1920,
                selectedBitrateBps: 8_000_000
            )
        )

        let point = mapper.map(x: 0.25, y: 0.75)

        XCTAssertEqual(point.x, 600)
        XCTAssertEqual(point.y, 950)
    }

    func testControlProtocolDecodesClipboardGetMessage() throws {
        let data = Data(
            """
            {
              "version": 1,
              "type": "clipboard.get",
              "sequence": 7,
              "timestampMs": 1234,
              "source": "browser"
            }
            """.utf8
        )

        guard case .clipboardGet(let message) = try ControlProtocol.decode(data) else {
            return XCTFail("Expected a clipboard get message.")
        }

        XCTAssertEqual(message.sequence, 7)
        XCTAssertEqual(message.source, "browser")
    }

    func testControlProtocolDecodesStreamStatsReportMessage() throws {
        let data = Data(
            """
            {
              "version": 1,
              "type": "stream.stats.report",
              "sequence": 9,
              "timestampMs": 1234,
              "stats": {
                "decodedFrames": 120,
                "droppedFrames": 2,
                "estimatedFramesPerSecond": 29.5,
                "frameWidth": 1280,
                "frameHeight": 720,
                "jitterMs": 12.5,
                "roundTripTimeMs": 44.0,
                "bitrateBps": 9000000
              }
            }
            """.utf8
        )

        guard case .streamStatsReport(let message) = try ControlProtocol.decode(data) else {
            return XCTFail("Expected a stream stats report message.")
        }

        XCTAssertEqual(message.stats.decodedFrames, 120)
        XCTAssertEqual(message.stats.frameWidth, 1280)
        XCTAssertEqual(message.stats.bitrateBps, 9_000_000)
    }
}
