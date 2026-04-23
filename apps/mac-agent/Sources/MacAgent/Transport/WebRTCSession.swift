import CoreMedia
import Foundation
import LiveKitWebRTC

final class WebRTCSession: NSObject {
    private let factory: LKRTCPeerConnectionFactory
    private let peerConnection: LKRTCPeerConnection
    private let screenCapturer: ScreenFrameCapturer
    private let videoSource: LKRTCVideoSource
    private let videoTrack: LKRTCVideoTrack
    private let candidateLock = NSLock()
    private let stateLock = NSLock()
    private var iceConnectionState = "new"
    private var localCandidates: [IceCandidate] = []
    private var sender: LKRTCRtpSender?
    private var signalingState = "new"

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

        videoSource = factory.videoSource(forScreenCast: true)
        screenCapturer = ScreenFrameCapturer(delegate: videoSource)
        videoTrack = factory.videoTrack(with: videoSource, trackId: "mac-screen")
        videoTrack.isEnabled = true

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
    }

    var diagnostics: MediaDiagnostics {
        var diagnostics = screenCapturer.diagnostics

        candidateLock.lock()
        diagnostics.localCandidates = localCandidates.count
        candidateLock.unlock()

        stateLock.lock()
        diagnostics.signalingState = signalingState
        diagnostics.iceConnectionState = iceConnectionState
        stateLock.unlock()

        diagnostics.senderAttached = sender != nil
        diagnostics.senderTrackEnabled = sender?.track?.isEnabled ?? false
        diagnostics.senderTrackReadyState = readyStateName(sender?.track?.readyState)
        return diagnostics
    }

    func createAnswer(for offer: SessionDescription, captureConfiguration: CaptureConfiguration) async throws -> SessionDescription {
        let remoteDescription = LKRTCSessionDescription(type: .offer, sdp: offer.sdp)
        try await setRemoteDescription(remoteDescription)
        configureVideoSource(captureConfiguration)
        attachVideoTrackIfNeeded()

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

    private func configureVideoSource(_ captureConfiguration: CaptureConfiguration) {
        videoSource.adaptOutputFormat(
            toWidth: Int32(captureConfiguration.width),
            height: Int32(captureConfiguration.height),
            fps: Int32(captureConfiguration.framesPerSecond)
        )
    }

    private func attachVideoTrackIfNeeded() {
        guard sender == nil else {
            return
        }

        if let transceiver = peerConnection.transceivers.first(where: { $0.mediaType == .video }) {
            transceiver.sender.track = videoTrack
            transceiver.sender.streamIds = ["screen"]
            var directionError: NSError?
            transceiver.setDirection(.sendOnly, error: &directionError)
            if let directionError {
                print("macvm: failed to set video transceiver sendOnly: \(directionError.localizedDescription)")
            }
            sender = transceiver.sender
            return
        }

        let initOptions = LKRTCRtpTransceiverInit()
        initOptions.direction = .sendOnly
        initOptions.streamIds = ["screen"]
        sender = peerConnection.addTransceiver(with: videoTrack, init: initOptions)?.sender
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

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange stateChanged: LKRTCSignalingState) {
        stateLock.lock()
        signalingState = signalingStateName(stateChanged)
        stateLock.unlock()
    }
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: LKRTCPeerConnection) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {
        stateLock.lock()
        iceConnectionState = iceConnectionStateName(newState)
        stateLock.unlock()
    }
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceGatheringState) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove candidates: [LKRTCIceCandidate]) {}
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didOpen dataChannel: LKRTCDataChannel) {}
}

private func signalingStateName(_ state: LKRTCSignalingState) -> String {
    switch state {
    case .stable:
        "stable"
    case .haveLocalOffer:
        "haveLocalOffer"
    case .haveLocalPrAnswer:
        "haveLocalPrAnswer"
    case .haveRemoteOffer:
        "haveRemoteOffer"
    case .haveRemotePrAnswer:
        "haveRemotePrAnswer"
    case .closed:
        "closed"
    @unknown default:
        "unknown"
    }
}

private func iceConnectionStateName(_ state: LKRTCIceConnectionState) -> String {
    switch state {
    case .new:
        "new"
    case .checking:
        "checking"
    case .connected:
        "connected"
    case .completed:
        "completed"
    case .failed:
        "failed"
    case .disconnected:
        "disconnected"
    case .closed:
        "closed"
    case .count:
        "count"
    @unknown default:
        "unknown"
    }
}

private func readyStateName(_ state: LKRTCMediaStreamTrackState?) -> String {
    guard let state else {
        return "none"
    }

    switch state {
    case .live:
        return "live"
    case .ended:
        return "ended"
    @unknown default:
        return "unknown"
    }
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
