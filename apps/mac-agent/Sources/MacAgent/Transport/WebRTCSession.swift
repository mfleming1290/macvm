import CoreMedia
import Foundation
import LiveKitWebRTC

final class WebRTCSession: NSObject {
    private let factory: LKRTCPeerConnectionFactory
    private let peerConnection: LKRTCPeerConnection
    private let screenCapturer: ScreenFrameCapturer
    private let candidateLock = NSLock()
    private var localCandidates: [IceCandidate] = []

    override init() {
        LKRTCInitializeSSL()

        let encoderFactory = LKRTCDefaultVideoEncoderFactory()
        let decoderFactory = LKRTCDefaultVideoDecoderFactory()
        factory = LKRTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )

        let configuration = LKRTCConfiguration()
        configuration.sdpSemantics = .unifiedPlan
        configuration.iceServers = [
            LKRTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]

        let constraints = LKRTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )

        let videoSource = factory.videoSource()
        screenCapturer = ScreenFrameCapturer(delegate: videoSource)

        guard let peerConnection = factory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: nil
        ) else {
            fatalError("Unable to create WebRTC peer connection.")
        }

        self.peerConnection = peerConnection
        super.init()

        self.peerConnection.delegate = self
        let videoTrack = factory.videoTrack(with: videoSource, trackId: "mac-screen")
        self.peerConnection.add(videoTrack, streamIds: ["screen"])
    }

    func createAnswer(for offer: SessionDescription) async throws -> SessionDescription {
        let remoteDescription = LKRTCSessionDescription(type: .offer, sdp: offer.sdp)
        try await setRemoteDescription(remoteDescription)

        let constraints = LKRTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        let answer = try await answer(for: constraints)
        try await setLocalDescription(answer)

        return SessionDescription(type: "answer", sdp: answer.sdp)
    }

    func capture(sampleBuffer: CMSampleBuffer) {
        screenCapturer.capture(sampleBuffer: sampleBuffer)
    }

    func addRemoteCandidate(_ candidate: IceCandidate) {
        let rtcCandidate = LKRTCIceCandidate(
            sdp: candidate.candidate,
            sdpMLineIndex: Int32(candidate.sdpMLineIndex ?? 0),
            sdpMid: candidate.sdpMid
        )
        peerConnection.add(rtcCandidate) { _ in }
    }

    func localCandidates(since cursor: Int) -> (candidates: [IceCandidate], nextCursor: Int) {
        candidateLock.lock()
        defer { candidateLock.unlock() }

        if cursor >= localCandidates.count {
            return ([], localCandidates.count)
        }

        return (Array(localCandidates[cursor...]), localCandidates.count)
    }

    func close() {
        peerConnection.close()
    }

    private func setRemoteDescription(_ description: LKRTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peerConnection.setRemoteDescription(description) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func setLocalDescription(_ description: LKRTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peerConnection.setLocalDescription(description) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func answer(for constraints: LKRTCMediaConstraints) async throws -> LKRTCSessionDescription {
        try await withCheckedThrowingContinuation { continuation in
            peerConnection.answer(for: constraints) { description, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let description else {
                    continuation.resume(throwing: WebRTCSessionError.missingAnswer)
                    return
                }

                continuation.resume(returning: description)
            }
        }
    }
}

extension WebRTCSession: LKRTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didGenerate candidate: LKRTCIceCandidate) {
        candidateLock.lock()
        defer { candidateLock.unlock() }

        localCandidates.append(
            IceCandidate(
                candidate: candidate.sdp,
                sdpMid: candidate.sdpMid,
                sdpMLineIndex: Int(candidate.sdpMLineIndex)
            )
        )
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange stateChanged: LKRTCSignalingState) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: LKRTCPeerConnection) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceGatheringState) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove candidates: [LKRTCIceCandidate]) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didOpen dataChannel: LKRTCDataChannel) {}
}

enum WebRTCSessionError: LocalizedError {
    case missingAnswer

    var errorDescription: String? {
        switch self {
        case .missingAnswer:
            "WebRTC did not produce an SDP answer."
        }
    }
}
