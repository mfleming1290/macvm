import CoreGraphics
import Foundation

final class InputInjector {
    private let source = CGEventSource(stateID: .hidSystemState)
    private var lastMousePosition = CGPoint.zero

    func moveMouse(to point: CGPoint, pressedButtons: Set<MouseButton>) throws {
        lastMousePosition = point
        let eventType: CGEventType
        let button: CGMouseButton

        if pressedButtons.contains(.left) {
            eventType = .leftMouseDragged
            button = .left
        } else if pressedButtons.contains(.right) {
            eventType = .rightMouseDragged
            button = .right
        } else {
            eventType = .mouseMoved
            button = .left
        }

        try postMouse(type: eventType, button: button, point: point)
    }

    func setMouseButton(_ button: MouseButton, isDown: Bool, at point: CGPoint) throws {
        lastMousePosition = point
        let eventType: CGEventType
        let cgButton: CGMouseButton

        switch (button, isDown) {
        case (.left, true):
            eventType = .leftMouseDown
            cgButton = .left
        case (.left, false):
            eventType = .leftMouseUp
            cgButton = .left
        case (.right, true):
            eventType = .rightMouseDown
            cgButton = .right
        case (.right, false):
            eventType = .rightMouseUp
            cgButton = .right
        }

        try postMouse(type: eventType, button: cgButton, point: point)
    }

    func scroll(deltaX: Double, deltaY: Double) throws {
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(-deltaY),
            wheel2: Int32(-deltaX),
            wheel3: 0
        ) else {
            throw InputInjectionError.eventCreationFailed
        }

        event.post(tap: .cghidEventTap)
    }

    func setKey(_ keyCode: UInt16, isDown: Bool, modifiers: ModifierState) throws {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else {
            throw InputInjectionError.eventCreationFailed
        }

        event.flags = flags(from: modifiers)
        event.post(tap: .cghidEventTap)
    }

    func release(buttons: [MouseButton], keyCodes: [UInt16]) throws {
        for button in buttons {
            try setMouseButton(button, isDown: false, at: lastMousePosition)
        }

        for keyCode in keyCodes {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
                throw InputInjectionError.eventCreationFailed
            }
            event.flags = []
            event.post(tap: .cghidEventTap)
        }
    }

    private func postMouse(type: CGEventType, button: CGMouseButton, point: CGPoint) throws {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button
        ) else {
            throw InputInjectionError.eventCreationFailed
        }

        event.post(tap: .cghidEventTap)
    }
}

func keyCode(for code: String) -> UInt16? {
    keyCodeMap[code]
}

private func flags(from modifiers: ModifierState) -> CGEventFlags {
    var flags = CGEventFlags()
    if modifiers.shift {
        flags.insert(.maskShift)
    }
    if modifiers.control {
        flags.insert(.maskControl)
    }
    if modifiers.alt {
        flags.insert(.maskAlternate)
    }
    if modifiers.meta {
        flags.insert(.maskCommand)
    }
    return flags
}

private let keyCodeMap: [String: UInt16] = [
    "KeyA": 0, "KeyS": 1, "KeyD": 2, "KeyF": 3, "KeyH": 4, "KeyG": 5, "KeyZ": 6, "KeyX": 7,
    "KeyC": 8, "KeyV": 9, "KeyB": 11, "KeyQ": 12, "KeyW": 13, "KeyE": 14, "KeyR": 15,
    "KeyY": 16, "KeyT": 17, "KeyO": 31, "KeyU": 32, "KeyI": 34, "KeyP": 35, "KeyL": 37,
    "KeyJ": 38, "KeyK": 40, "KeyN": 45, "KeyM": 46,
    "Digit1": 18, "Digit2": 19, "Digit3": 20, "Digit4": 21, "Digit6": 22, "Digit5": 23,
    "Digit9": 25, "Digit7": 26, "Digit8": 28, "Digit0": 29,
    "Equal": 24, "Minus": 27, "BracketRight": 30, "BracketLeft": 33, "Quote": 39,
    "Semicolon": 41, "Backslash": 42, "Comma": 43, "Slash": 44, "Period": 47, "Backquote": 50,
    "Enter": 36, "Tab": 48, "Space": 49, "Backspace": 51, "Escape": 53,
    "MetaLeft": 55, "MetaRight": 54, "ShiftLeft": 56, "CapsLock": 57, "AltLeft": 58,
    "ControlLeft": 59, "ShiftRight": 60, "AltRight": 61, "ControlRight": 62,
    "F17": 64, "F18": 79, "F19": 80, "F20": 90,
    "F5": 96, "F6": 97, "F7": 98, "F3": 99, "F8": 100, "F9": 101, "F11": 103,
    "F13": 105, "F16": 106, "F14": 107, "F10": 109, "F12": 111, "F15": 113,
    "Insert": 114, "Home": 115, "PageUp": 116, "Delete": 117, "F4": 118, "End": 119,
    "F2": 120, "PageDown": 121, "F1": 122, "ArrowLeft": 123, "ArrowRight": 124,
    "ArrowDown": 125, "ArrowUp": 126
]

enum InputInjectionError: LocalizedError {
    case eventCreationFailed
    case unsupportedKey(String)

    var errorDescription: String? {
        switch self {
        case .eventCreationFailed:
            "CoreGraphics could not create an input event."
        case .unsupportedKey(let code):
            "Unsupported keyboard code: \(code)."
        }
    }
}
