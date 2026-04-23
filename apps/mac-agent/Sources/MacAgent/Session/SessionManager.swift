import Foundation

final class SessionManager {
    var onSessionStatusChanged: ((String) -> Void)?

    private let captureService = ScreenCaptureService()
    private var activeSession: ActiveSession?

    var hasActiveSession: Bool {
        activeSession != nil
    }

    func createSession(from offer: SessionDescription) async throws -> CreateSessionResponse {
        try validateProtocolDescription(offer)
        await closeActiveSession()

        let sessionId = UUID().uuidString
        let webRTCSession = WebRTCSession()
        activeSession = ActiveSession(id: sessionId, webRTCSession: webRTCSession)
        onSessionStatusChanged?("Negotiating")

        captureService.onFrame = { [weak webRTCSession] sampleBuffer in
            webRTCSession?.capture(sampleBuffer: sampleBuffer)
        }

        let answer = try await webRTCSession.createAnswer(for: offer)
        try await captureService.start()
        onSessionStatusChanged?("Streaming")

        return CreateSessionResponse(
            version: protocolVersion,
            sessionId: sessionId,
            answer: answer
        )
    }

    func addIceCandidate(_ candidate: IceCandidate, to sessionId: String) throws {
        guard let activeSession, activeSession.id == sessionId else {
            throw SessionError.sessionNotFound
        }

        activeSession.webRTCSession.addRemoteCandidate(candidate)
    }

    func localCandidates(for sessionId: String, since cursor: Int) throws -> IceCandidatesResponse {
        guard let activeSession, activeSession.id == sessionId else {
            throw SessionError.sessionNotFound
        }

        let result = activeSession.webRTCSession.localCandidates(since: max(0, cursor))
        return IceCandidatesResponse(
            version: protocolVersion,
            candidates: result.candidates,
            nextCursor: result.nextCursor
        )
    }

    func closeSession(id sessionId: String) async {
        guard activeSession?.id == sessionId else {
            return
        }

        await closeActiveSession()
    }

    private func closeActiveSession() async {
        await captureService.stop()
        activeSession?.webRTCSession.close()
        activeSession = nil
        onSessionStatusChanged?("Waiting for viewer")
    }

    private func validateProtocolDescription(_ description: SessionDescription) throws {
        guard description.type == "offer", !description.sdp.isEmpty else {
            throw SessionError.invalidOffer
        }
    }
}

private struct ActiveSession {
    let id: String
    let webRTCSession: WebRTCSession
}

enum SessionError: LocalizedError {
    case invalidOffer
    case sessionNotFound

    var errorDescription: String? {
        switch self {
        case .invalidOffer:
            "The session offer is missing or invalid."
        case .sessionNotFound:
            "The requested session is not active."
        }
    }
}
