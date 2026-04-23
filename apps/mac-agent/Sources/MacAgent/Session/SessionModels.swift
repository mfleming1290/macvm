import Foundation

let protocolVersion = 1

struct SessionDescription: Codable {
    let type: String
    let sdp: String
}

struct IceCandidate: Codable {
    let candidate: String
    let sdpMid: String?
    let sdpMLineIndex: Int?

    var isValid: Bool {
        !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct CreateSessionRequest: Codable {
    let version: Int
    let offer: SessionDescription
    let stream: StreamQualitySettings?
}

struct StreamQualitySettings: Codable, Equatable {
    let maxBitrateBps: Int
    let resolutionPreset: String

    static let defaultSettings = StreamQualitySettings(
        maxBitrateBps: 8_000_000,
        resolutionPreset: "1080p"
    )

    var safeMaxBitrateBps: Int {
        min(50_000_000, max(1_000_000, maxBitrateBps))
    }

    var maxLongEdge: Int? {
        switch resolutionPreset {
        case "native":
            nil
        case "1440p":
            2_560
        case "720p":
            1_280
        default:
            1_920
        }
    }
}

struct CreateSessionResponse: Codable {
    let version: Int
    let sessionId: String
    let answer: SessionDescription
}

struct AddIceCandidateRequest: Codable {
    let version: Int
    let candidate: IceCandidate
}

struct IceCandidatesResponse: Codable {
    let version: Int
    let candidates: [IceCandidate]
    let nextCursor: Int
}

struct HealthResponse: Codable {
    let version: Int
    let status: String
    let activeSession: Bool
    let screenRecordingAllowed: Bool
    let accessibilityAllowed: Bool
    let sessionStatus: String
    let serverStatus: String
    let lastError: String?
    let media: MediaDiagnostics
    let control: ControlDiagnostics

    enum CodingKeys: String, CodingKey {
        case version
        case status
        case activeSession
        case screenRecordingAllowed
        case accessibilityAllowed
        case sessionStatus
        case serverStatus
        case lastError
        case media
        case control
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(status, forKey: .status)
        try container.encode(activeSession, forKey: .activeSession)
        try container.encode(screenRecordingAllowed, forKey: .screenRecordingAllowed)
        try container.encode(accessibilityAllowed, forKey: .accessibilityAllowed)
        try container.encode(sessionStatus, forKey: .sessionStatus)
        try container.encode(serverStatus, forKey: .serverStatus)
        try container.encode(lastError, forKey: .lastError)
        try container.encode(media, forKey: .media)
        try container.encode(control, forKey: .control)
    }
}

struct ErrorResponse: Codable {
    let version: Int
    let error: ResponseError
}

struct ResponseError: Codable {
    let code: String
    let message: String
}
