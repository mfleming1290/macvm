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
                displayFrame: CGRect(x: 100, y: 200, width: 2000, height: 1000)
            )
        )

        let point = mapper.map(x: 0.25, y: 0.75)

        XCTAssertEqual(point.x, 600)
        XCTAssertEqual(point.y, 950)
    }
}
