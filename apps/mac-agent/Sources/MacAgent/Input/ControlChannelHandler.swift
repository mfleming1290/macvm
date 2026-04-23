import Foundation
import LiveKitWebRTC

final class ControlChannelHandler: NSObject {
    private let clipboardQueue = DispatchQueue(label: "macvm.clipboard")
    private let clipboardService = ClipboardService()
    private let inputController: InputController
    private let onStreamQualityUpdate: (StreamQualitySettings) -> Void
    private var dataChannel: LKRTCDataChannel?

    init(
        inputController: InputController,
        onStreamQualityUpdate: @escaping (StreamQualitySettings) -> Void
    ) {
        self.inputController = inputController
        self.onStreamQualityUpdate = onStreamQualityUpdate
    }

    var diagnostics: ControlDiagnostics {
        inputController.diagnostics
    }

    func attach(_ dataChannel: LKRTCDataChannel) {
        self.dataChannel = dataChannel
        dataChannel.delegate = self
        inputController.setChannelState(channelStateName(dataChannel.readyState))
        print("macvm control: data channel opened label=\(dataChannel.label)")
    }

    func resetAndClose() {
        inputController.resetPressedState()
        dataChannel?.delegate = nil
        dataChannel?.close()
        dataChannel = nil
        inputController.setChannelState("closed")
    }
}

extension ControlChannelHandler: LKRTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: LKRTCDataChannel) {
        let state = channelStateName(dataChannel.readyState)
        inputController.setChannelState(state)
        print("macvm control: data channel state=\(state)")
    }

    func dataChannel(_ dataChannel: LKRTCDataChannel, didReceiveMessageWith buffer: LKRTCDataBuffer) {
        guard !buffer.isBinary else {
            inputController.recordControlError("Ignored binary data channel message.")
            return
        }

        do {
            let message = try ControlProtocol.decode(buffer.data)
            switch message {
            case .streamQuality(let message):
                onStreamQualityUpdate(message.settings)
            case .clipboardSet(let message):
                handleClipboardSet(message)
            case .clipboardGet(let message):
                handleClipboardGet(message)
            case .clipboardValue, .clipboardError:
                inputController.recordClipboardFailure(
                    type: message.type,
                    message: "Ignored clipboard response message sent from the remote browser."
                )
            default:
                inputController.handle(message)
            }
        } catch {
            inputController.recordControlError("Failed to decode control message: \(error.localizedDescription)")
        }
    }

    private func handleClipboardSet(_ message: ClipboardSetControlMessage) {
        clipboardQueue.async { [weak self] in
            guard let self else {
                return
            }

            do {
                try clipboardService.setText(message.text)
                inputController.recordClipboardWrite(textLength: message.text.count, type: message.type)
                print("macvm clipboard: wrote \(message.text.count) chars from \(message.source)")
            } catch let error as ClipboardError {
                inputController.recordClipboardFailure(type: message.type, message: error.localizedDescription)
                sendClipboardError(
                    code: error.code,
                    message: error.localizedDescription,
                    replyToSequence: message.sequence
                )
            } catch {
                inputController.recordClipboardFailure(type: message.type, message: error.localizedDescription)
                sendClipboardError(
                    code: ClipboardError.writeFailed.code,
                    message: error.localizedDescription,
                    replyToSequence: message.sequence
                )
            }
        }
    }

    private func handleClipboardGet(_ message: ClipboardGetControlMessage) {
        clipboardQueue.async { [weak self] in
            guard let self else {
                return
            }

            do {
                switch try clipboardService.readText() {
                case .text(let text):
                    inputController.recordClipboardRead(textLength: text.count, type: message.type)
                    print("macvm clipboard: read \(text.count) chars for \(message.source)")
                    sendClipboardValue(text: text, replyToSequence: message.sequence)
                case .empty:
                    let error = ClipboardError.empty
                    inputController.recordClipboardFailure(type: message.type, message: error.localizedDescription)
                    sendClipboardError(code: error.code, message: error.localizedDescription, replyToSequence: message.sequence)
                case .nonText:
                    let error = ClipboardError.nonText
                    inputController.recordClipboardFailure(type: message.type, message: error.localizedDescription)
                    sendClipboardError(code: error.code, message: error.localizedDescription, replyToSequence: message.sequence)
                }
            } catch let error as ClipboardError {
                inputController.recordClipboardFailure(type: message.type, message: error.localizedDescription)
                sendClipboardError(code: error.code, message: error.localizedDescription, replyToSequence: message.sequence)
            } catch {
                inputController.recordClipboardFailure(type: message.type, message: error.localizedDescription)
                sendClipboardError(
                    code: ClipboardError.readFailed.code,
                    message: error.localizedDescription,
                    replyToSequence: message.sequence
                )
            }
        }
    }

    private func sendClipboardValue(text: String, replyToSequence: Int) {
        let message = ClipboardValueControlMessage(
            version: protocolVersion,
            type: "clipboard.value",
            sequence: nextSequence(),
            timestampMs: Date().timeIntervalSince1970 * 1000,
            source: "agent",
            replyToSequence: replyToSequence,
            text: text
        )
        send(message)
    }

    private func sendClipboardError(code: String, message: String, replyToSequence: Int) {
        let errorMessage = ClipboardErrorControlMessage(
            version: protocolVersion,
            type: "clipboard.error",
            sequence: nextSequence(),
            timestampMs: Date().timeIntervalSince1970 * 1000,
            source: "agent",
            replyToSequence: replyToSequence,
            code: code,
            message: message
        )
        send(errorMessage)
    }

    private func send<T: Encodable>(_ message: T) {
        guard let dataChannel, dataChannel.readyState == .open else {
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            _ = dataChannel.sendData(LKRTCDataBuffer(data: data, isBinary: false))
        } catch {
            inputController.recordClipboardFailure(type: "clipboard.error", message: "Failed to send clipboard response: \(error.localizedDescription)")
        }
    }
}

private var clipboardSequenceLock = NSLock()
private var clipboardSequenceCounter = 1

private func nextSequence() -> Int {
    clipboardSequenceLock.lock()
    defer { clipboardSequenceLock.unlock() }
    let sequence = clipboardSequenceCounter
    clipboardSequenceCounter += 1
    return sequence
}

private func channelStateName(_ state: LKRTCDataChannelState) -> String {
    switch state {
    case .connecting:
        "connecting"
    case .open:
        "open"
    case .closing:
        "closing"
    case .closed:
        "closed"
    @unknown default:
        "closed"
    }
}
