import Foundation

enum AgentError: LocalizedError {
    case captureFailed(String)
    case invalidIceCandidate
    case invalidInput
    case invalidJSON
    case invalidOffer
    case negotiationFailed(String)
    case notFound
    case permissionMissing
    case sessionNotFound
    case unsupportedProtocolVersion

    var code: String {
        switch self {
        case .captureFailed:
            "capture_failed"
        case .invalidIceCandidate:
            "invalid_ice_candidate"
        case .invalidInput:
            "invalid_input"
        case .invalidJSON:
            "invalid_json"
        case .invalidOffer:
            "invalid_offer"
        case .negotiationFailed:
            "negotiation_failed"
        case .notFound:
            "not_found"
        case .permissionMissing:
            "permission_missing"
        case .sessionNotFound:
            "session_not_found"
        case .unsupportedProtocolVersion:
            "unsupported_protocol_version"
        }
    }

    var statusCode: Int {
        switch self {
        case .invalidIceCandidate, .invalidInput, .invalidJSON, .invalidOffer, .unsupportedProtocolVersion:
            400
        case .permissionMissing:
            403
        case .sessionNotFound, .notFound:
            404
        case .captureFailed, .negotiationFailed:
            500
        }
    }

    var errorDescription: String? {
        switch self {
        case .captureFailed(let message):
            "Screen capture failed: \(message)"
        case .invalidIceCandidate:
            "The ICE candidate is missing or invalid."
        case .invalidInput:
            "The input control message is missing or invalid."
        case .invalidJSON:
            "The request body is not valid JSON for this endpoint."
        case .invalidOffer:
            "The session offer is missing or invalid."
        case .negotiationFailed(let message):
            "WebRTC negotiation failed: \(message)"
        case .notFound:
            "The requested endpoint does not exist."
        case .permissionMissing:
            "Screen Recording permission is required before starting a stream."
        case .sessionNotFound:
            "The requested session is not active."
        case .unsupportedProtocolVersion:
            "Unsupported protocol version."
        }
    }
}
