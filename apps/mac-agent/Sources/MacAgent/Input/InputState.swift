import Foundation

final class InputState {
    private let lock = NSLock()
    private var buttons = Set<MouseButton>()
    private var keyCodes = Set<UInt16>()

    var pressedButtons: Set<MouseButton> {
        lock.lock()
        defer { lock.unlock() }
        return buttons
    }

    var pressedButtonCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return buttons.count
    }

    var pressedKeyCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return keyCodes.count
    }

    func setButton(_ button: MouseButton, isDown: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if isDown {
            buttons.insert(button)
        } else {
            buttons.remove(button)
        }
    }

    func setKey(_ keyCode: UInt16, isDown: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if isDown {
            keyCodes.insert(keyCode)
        } else {
            keyCodes.remove(keyCode)
        }
    }

    func clear() -> (buttons: [MouseButton], keyCodes: [UInt16]) {
        lock.lock()
        defer { lock.unlock() }
        let releasedButtons = Array(buttons)
        let releasedKeyCodes = Array(keyCodes)
        buttons.removeAll()
        keyCodes.removeAll()
        return (releasedButtons, releasedKeyCodes)
    }
}
