import XCTest
@testable import MacAgent

final class ProtocolParityTests: XCTestCase {
    func testSharedStreamSettingsFixturesMatchSwiftValidation() throws {
        let valid = try decodeFixture("valid-stream-settings.json", as: StreamQualitySettings.self)
        XCTAssertTrue(valid.hasSupportedResolutionPreset)
        XCTAssertEqual(valid.safeMaxBitrateBps, 20_000_000)
        XCTAssertEqual(valid.safeFramesPerSecond, 45)
        XCTAssertEqual(valid.maxLongEdge, 2_560)

        let invalid = try decodeFixture("invalid-stream-settings.json", as: StreamQualitySettings.self)
        XCTAssertFalse(invalid.hasSupportedResolutionPreset)
        XCTAssertEqual(invalid.safeFramesPerSecond, 30)
    }

    func testStreamSettingsClampBitrateAndNormalizeFramesPerSecond() {
        let lowBitrate = StreamQualitySettings(maxBitrateBps: 999_999, framesPerSecond: 30, resolutionPreset: "1080p")
        let highBitrate = StreamQualitySettings(maxBitrateBps: 100_000_001, framesPerSecond: 60, resolutionPreset: "720p")
        let invalidFPS = StreamQualitySettings(maxBitrateBps: 20_000_000, framesPerSecond: 24, resolutionPreset: "native")

        XCTAssertEqual(lowBitrate.safeMaxBitrateBps, 1_000_000)
        XCTAssertEqual(highBitrate.safeMaxBitrateBps, 100_000_000)
        XCTAssertEqual(invalidFPS.safeFramesPerSecond, 30)
    }

    func testSharedValidControlMessagesDecode() throws {
        let messages = try decodeFixture("valid-control-messages.json", as: [JSONValue].self)

        for message in messages {
            XCTAssertNoThrow(try ControlProtocol.decode(message.data()), "Expected valid control message fixture to decode")
        }
    }

    func testSharedInvalidControlMessagesAreRejected() throws {
        let cases = try decodeFixture("invalid-control-messages.json", as: [InvalidControlFixture].self)

        for testCase in cases {
            XCTAssertThrowsError(try ControlProtocol.decode(testCase.message.data()), testCase.label)
        }
    }

    func testSessionAndIceFixturesDecodeAndValidate() throws {
        let session = try decodeFixture("valid-create-session-request.json", as: CreateSessionRequest.self)
        XCTAssertEqual(session.version, protocolVersion)
        XCTAssertEqual(session.offer.type, "offer")
        XCTAssertEqual(session.offer.sdp, "v=0")
        XCTAssertEqual(session.stream?.hasSupportedResolutionPreset, true)

        let invalidSession = try decodeFixture("invalid-create-session-request.json", as: CreateSessionRequest.self)
        XCTAssertNotEqual(invalidSession.version, protocolVersion)
        XCTAssertEqual(invalidSession.offer.type, "answer")
        XCTAssertEqual(invalidSession.stream?.hasSupportedResolutionPreset, false)
        XCTAssertEqual(invalidSession.stream?.safeFramesPerSecond, 30)

        let ice = try decodeFixture("valid-add-ice-candidate-request.json", as: AddIceCandidateRequest.self)
        XCTAssertEqual(ice.version, protocolVersion)
        XCTAssertTrue(ice.candidate.isValid)

        let invalidIce = try decodeFixture("invalid-add-ice-candidate-request.json", as: AddIceCandidateRequest.self)
        XCTAssertFalse(invalidIce.candidate.isValid)
    }

    func testHealthAndIceResponseFixturesDecode() throws {
        let health = try decodeFixture("valid-health-response.json", as: HealthResponse.self)
        XCTAssertEqual(health.version, protocolVersion)
        XCTAssertEqual(health.status, "ok")
        XCTAssertEqual(health.media.selectedBitrateBps, 20_000_000)
        XCTAssertEqual(health.control.channelState, "open")

        let ice = try decodeFixture("valid-ice-candidates-response.json", as: IceCandidatesResponse.self)
        XCTAssertEqual(ice.version, protocolVersion)
        XCTAssertEqual(ice.nextCursor, 1)
        XCTAssertTrue(ice.candidates.allSatisfy(\.isValid))
    }

    func testAgentErrorsEmitDocumentedErrorCodes() throws {
        let expectedCodes = Set(try decodeFixture("valid-error-responses.json", as: [ErrorResponse].self).map(\.error.code))
        let emittedCodes = Set([
            AgentError.captureFailed("failed").code,
            AgentError.invalidIceCandidate.code,
            AgentError.invalidInput.code,
            AgentError.invalidJSON.code,
            AgentError.invalidOffer.code,
            AgentError.negotiationFailed("failed").code,
            AgentError.notFound.code,
            AgentError.permissionMissing.code,
            AgentError.sessionNotFound.code,
            AgentError.unsupportedProtocolVersion.code
        ])

        XCTAssertEqual(emittedCodes, expectedCodes)

        let response = HTTPResponse.error(.invalidInput)
        let decoded = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
        XCTAssertEqual(decoded.version, protocolVersion)
        XCTAssertEqual(decoded.error.code, "invalid_input")
    }
}

private struct InvalidControlFixture: Decodable {
    let label: String
    let message: JSONValue
}

private enum JSONValue: Codable {
    case array([JSONValue])
    case bool(Bool)
    case null
    case number(Double)
    case object([String: JSONValue])
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .array(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .number(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }

    func data() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

private func decodeFixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
    let data = try Data(contentsOf: fixtureURL(name))
    return try JSONDecoder().decode(type, from: data)
}

private func fixtureURL(_ name: String) throws -> URL {
    var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    while true {
        let candidate = directory.appendingPathComponent("protocol-fixtures").appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        let parent = directory.deletingLastPathComponent()
        if parent.path == directory.path {
            throw NSError(
                domain: "ProtocolParityTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not find protocol-fixtures/\(name)"]
            )
        }
        directory = parent
    }
}
