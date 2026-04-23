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

    func testHealthResponseIncludesRuntimeStatusFields() throws {
        let response = HealthResponse(
            version: protocolVersion,
            status: "permissionMissing",
            activeSession: false,
            screenRecordingAllowed: false,
            accessibilityAllowed: false,
            sessionStatus: "Permission missing",
            serverStatus: "Listening on :8080",
            lastError: "Screen Recording permission is required before starting a stream.",
            media: .empty,
            control: .empty
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(HealthResponse.self, from: data)

        XCTAssertEqual(decoded.status, "permissionMissing")
        XCTAssertFalse(decoded.screenRecordingAllowed)
        XCTAssertEqual(decoded.lastError, "Screen Recording permission is required before starting a stream.")
    }

    func testHealthResponseEncodesNilLastErrorAsNull() throws {
        let response = HealthResponse(
            version: protocolVersion,
            status: "ok",
            activeSession: false,
            screenRecordingAllowed: true,
            accessibilityAllowed: true,
            sessionStatus: "Waiting for viewer",
            serverStatus: "Listening on :8080",
            lastError: nil,
            media: .empty,
            control: .empty
        )

        let json = String(data: try JSONEncoder().encode(response), encoding: .utf8)

        XCTAssertTrue(json?.contains(#""lastError":null"#) == true)
    }

    func testMediaDiagnosticsEncodesNilFrameFieldsAsNull() throws {
        let json = String(data: try JSONEncoder().encode(MediaDiagnostics.empty), encoding: .utf8)

        XCTAssertTrue(json?.contains(#""lastFrameWidth":null"#) == true)
        XCTAssertTrue(json?.contains(#""lastFrameHeight":null"#) == true)
        XCTAssertTrue(json?.contains(#""lastPixelFormat":null"#) == true)
        XCTAssertTrue(json?.contains(#""lastTimestampNs":null"#) == true)
    }

    func testIceCandidateValidationRejectsEmptyCandidates() {
        XCTAssertTrue(IceCandidate(candidate: "candidate:1 1 udp", sdpMid: "0", sdpMLineIndex: 0).isValid)
        XCTAssertFalse(IceCandidate(candidate: "   ", sdpMid: "0", sdpMLineIndex: 0).isValid)
    }
}
