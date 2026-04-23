import XCTest
@testable import MacAgent

final class ProtocolCodingTests: XCTestCase {
    func testCreateSessionRequestDecodes() throws {
        let data = Data(
            """
            {
              "version": 1,
              "offer": {
                "type": "offer",
                "sdp": "v=0"
              }
            }
            """.utf8
        )

        let request = try JSONDecoder().decode(CreateSessionRequest.self, from: data)

        XCTAssertEqual(request.version, 1)
        XCTAssertEqual(request.offer.type, "offer")
        XCTAssertEqual(request.offer.sdp, "v=0")
    }
}
