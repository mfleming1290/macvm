import Foundation

final class SessionManager {
    var onSessionStatusChanged: ((String) -> Void)?

    private let captureService = ScreenCaptureService()
    private var activeSession: ActiveSession?
    private(set) var lastError: String?
    private(set) var status = "Waiting for viewer"

    var hasActiveSession: Bool {
        activeSession != nil
    }

    var mediaDiagnostics: MediaDiagnostics {
        var diagnostics = captureService.diagnostics
        if let webRTCDiagnostics = activeSession?.webRTCSession.diagnostics {
            diagnostics.capturerFrames = webRTCDiagnostics.capturerFrames
            diagnostics.sourceFrames = webRTCDiagnostics.sourceFrames
            diagnostics.lastTimestampNs = webRTCDiagnostics.lastTimestampNs
            diagnostics.senderAttached = webRTCDiagnostics.senderAttached
            diagnostics.senderTrackEnabled = webRTCDiagnostics.senderTrackEnabled
            diagnostics.senderTrackReadyState = webRTCDiagnostics.senderTrackReadyState
            diagnostics.selectedBitrateBps = webRTCDiagnostics.selectedBitrateBps
            diagnostics.localCandidates = webRTCDiagnostics.localCandidates
            diagnostics.signalingState = webRTCDiagnostics.signalingState
            diagnostics.iceConnectionState = webRTCDiagnostics.iceConnectionState
        }
        return diagnostics
    }

    var controlDiagnostics: ControlDiagnostics {
        activeSession?.webRTCSession.controlDiagnostics ?? .empty
    }

    var healthStatus: String {
        if !ScreenRecordingPermission.isGranted {
            return "permissionMissing"
        }

        if status.hasPrefix("Capture failed") {
            return "captureFailed"
        }

        if status.hasPrefix("Negotiation failed") {
            return "negotiationFailed"
        }

        return "ok"
    }

    func createSession(
        from offer: SessionDescription,
        streamSettings: StreamQualitySettings = .defaultSettings
    ) async throws -> CreateSessionResponse {
        try validateProtocolDescription(offer)
        guard ScreenRecordingPermission.isGranted else {
            setFailureStatus("Permission missing", message: AgentError.permissionMissing.localizedDescription)
            throw AgentError.permissionMissing
        }

        await closeActiveSession()

        let sessionId = UUID().uuidString
        let webRTCSession = WebRTCSession()
        activeSession = ActiveSession(id: sessionId, webRTCSession: webRTCSession)
        setStatus("Negotiating")

        captureService.onFrame = { [weak webRTCSession] sampleBuffer in
            webRTCSession?.capture(sampleBuffer: sampleBuffer)
        }

        do {
            let captureConfiguration: CaptureConfiguration
            do {
                captureConfiguration = try await captureService.start(
                    streamSettings: streamSettings
                )
            } catch {
                await closeActiveSession()
                let message = error.localizedDescription
                setFailureStatus("Capture failed", message: message)
                throw AgentError.captureFailed(message)
            }

            let answer = try await webRTCSession.createAnswer(
                for: offer,
                captureConfiguration: captureConfiguration
            )
            setStatus("Streaming")
            return CreateSessionResponse(
                version: protocolVersion,
                sessionId: sessionId,
                answer: answer
            )
        } catch let error as AgentError {
            throw error
        } catch {
            await closeActiveSession()
            let message = error.localizedDescription
            setFailureStatus("Negotiation failed", message: message)
            throw AgentError.negotiationFailed(message)
        }
    }

    func addIceCandidate(_ candidate: IceCandidate, to sessionId: String) throws {
        guard let activeSession, activeSession.id == sessionId else {
            throw AgentError.sessionNotFound
        }

        guard candidate.isValid else {
            throw AgentError.invalidIceCandidate
        }

        activeSession.webRTCSession.addRemoteCandidate(candidate)
    }

    func localCandidates(for sessionId: String, since cursor: Int) throws -> IceCandidatesResponse {
        guard let activeSession, activeSession.id == sessionId else {
            throw AgentError.sessionNotFound
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
        captureService.onFrame = nil
        activeSession?.webRTCSession.close()
        activeSession = nil
        setStatus("Waiting for viewer")
    }

    private func validateProtocolDescription(_ description: SessionDescription) throws {
        guard description.type == "offer", !description.sdp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentError.invalidOffer
        }
    }

    private func setStatus(_ status: String) {
        self.status = status
        lastError = nil
        onSessionStatusChanged?(status)
    }

    private func setFailureStatus(_ status: String, message: String) {
        self.status = status
        lastError = message
        onSessionStatusChanged?("\(status): \(message)")
    }
}

private struct ActiveSession {
    let id: String
    let webRTCSession: WebRTCSession
}
