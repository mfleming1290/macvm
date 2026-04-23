import Foundation
import LiveKitWebRTC

final class ControlChannelHandler: NSObject {
    private let inputController: InputController
    private var dataChannel: LKRTCDataChannel?

    init(inputController: InputController) {
        self.inputController = inputController
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
            inputController.handle(message)
        } catch {
            inputController.recordControlError("Failed to decode control message: \(error.localizedDescription)")
        }
    }
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
