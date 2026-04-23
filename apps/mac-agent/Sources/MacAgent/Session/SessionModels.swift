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
    let sessionStatus: String
    let serverStatus: String
    let lastError: String?

    enum CodingKeys: String, CodingKey {
        case version
        case status
        case activeSession
        case screenRecordingAllowed
        case sessionStatus
        case serverStatus
        case lastError
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(status, forKey: .status)
        try container.encode(activeSession, forKey: .activeSession)
        try container.encode(screenRecordingAllowed, forKey: .screenRecordingAllowed)
        try container.encode(sessionStatus, forKey: .sessionStatus)
        try container.encode(serverStatus, forKey: .serverStatus)
        try container.encode(lastError, forKey: .lastError)
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
