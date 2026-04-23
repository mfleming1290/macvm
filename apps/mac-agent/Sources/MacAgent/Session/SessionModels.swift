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
}
