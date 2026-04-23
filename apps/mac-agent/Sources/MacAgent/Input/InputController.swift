import Foundation

final class InputController {
    private let diagnosticsLock = NSLock()
    private let injector = InputInjector()
    private let mapper = DisplayCoordinateMapper()
    private let state = InputState()
    private var currentDiagnostics = ControlDiagnostics.empty

    var diagnostics: ControlDiagnostics {
        diagnosticsLock.lock()
        var diagnostics = currentDiagnostics
        diagnostics.accessibilityAllowed = AccessibilityPermission.isGranted
        diagnostics.pressedKeys = state.pressedKeyCount
        diagnostics.pressedButtons = state.pressedButtonCount
        diagnosticsLock.unlock()
        return diagnostics
    }

    func update(captureConfiguration: CaptureConfiguration) {
        mapper.update(captureConfiguration: captureConfiguration)
    }

    func setChannelState(_ channelState: String) {
        updateDiagnostics { diagnostics in
            diagnostics.channelState = channelState
            diagnostics.accessibilityAllowed = AccessibilityPermission.isGranted
        }
    }

    func handle(_ message: ControlMessage) {
        updateDiagnostics { diagnostics in
            diagnostics.receivedMessages += 1
            diagnostics.lastMessageType = message.type
            diagnostics.lastError = nil
            diagnostics.accessibilityAllowed = AccessibilityPermission.isGranted
        }

        do {
            switch message {
            case .reset:
                resetPressedState()
            case .streamQuality:
                break
            case .mouseMove(let message):
                try requireAccessibility()
                let point = mapper.map(x: message.x, y: message.y)
                try injector.moveMouse(to: point, pressedButtons: state.pressedButtons)
                recordInjected(point: point)
            case .mouseButton(let message):
                try requireAccessibility()
                let point = mapper.map(x: message.x, y: message.y)
                state.setButton(message.button, isDown: message.action == .down)
                try injector.setMouseButton(message.button, isDown: message.action == .down, at: point)
                recordInjected(point: point)
            case .mouseWheel(let message):
                try requireAccessibility()
                let point = mapper.map(x: message.x, y: message.y)
                try injector.moveMouse(to: point, pressedButtons: state.pressedButtons)
                try injector.scroll(deltaX: message.deltaX, deltaY: message.deltaY)
                recordInjected(point: point, eventCount: 2)
            case .keyboardKey(let message):
                try requireAccessibility()
                guard let keyCode = keyCode(for: message.code) else {
                    throw InputInjectionError.unsupportedKey(message.code)
                }
                state.setKey(keyCode, isDown: message.action == .down)
                try injector.setKey(keyCode, isDown: message.action == .down, modifiers: message.modifiers)
                recordInjected()
            }
        } catch {
            recordError(error.localizedDescription)
        }
    }

    func resetPressedState() {
        let released = state.clear()
        do {
            if AccessibilityPermission.isGranted {
                try injector.release(buttons: released.buttons, keyCodes: released.keyCodes)
            }
            updateDiagnostics { diagnostics in
                diagnostics.resetCount += 1
                diagnostics.pressedKeys = 0
                diagnostics.pressedButtons = 0
                diagnostics.accessibilityAllowed = AccessibilityPermission.isGranted
            }
        } catch {
            recordError(error.localizedDescription)
        }
    }

    func recordControlError(_ message: String) {
        recordError(message)
    }

    private func recordInjected(point: CGPoint? = nil, eventCount: Int = 1) {
        updateDiagnostics { diagnostics in
            diagnostics.injectedEvents += eventCount
            diagnostics.pressedKeys = state.pressedKeyCount
            diagnostics.pressedButtons = state.pressedButtonCount
            diagnostics.accessibilityAllowed = AccessibilityPermission.isGranted
            if let point {
                diagnostics.lastMappedX = point.x
                diagnostics.lastMappedY = point.y
            }
        }
    }

    private func requireAccessibility() throws {
        guard AccessibilityPermission.isGranted else {
            throw InputControlError.accessibilityMissing
        }
    }

    private func recordError(_ message: String) {
        print("macvm control: \(message)")
        updateDiagnostics { diagnostics in
            diagnostics.lastError = message
            diagnostics.accessibilityAllowed = AccessibilityPermission.isGranted
            diagnostics.pressedKeys = state.pressedKeyCount
            diagnostics.pressedButtons = state.pressedButtonCount
        }
    }

    private func updateDiagnostics(_ update: (inout ControlDiagnostics) -> Void) {
        diagnosticsLock.lock()
        update(&currentDiagnostics)
        diagnosticsLock.unlock()
    }
}

enum InputControlError: LocalizedError {
    case accessibilityMissing

    var errorDescription: String? {
        switch self {
        case .accessibilityMissing:
            "Accessibility permission is required before remote input can be injected."
        }
    }
}
