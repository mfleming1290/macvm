import Foundation

enum MouseButton: String, Codable, Hashable {
    case left
    case right
}

enum InputAction: String, Codable {
    case down
    case up
}

struct ModifierState: Codable {
    let shift: Bool
    let control: Bool
    let alt: Bool
    let meta: Bool
}

struct MouseMoveControlMessage: Codable {
    let version: Int
    let type: String
    let sequence: Int
    let timestampMs: Double
    let x: Double
    let y: Double
    let buttons: [MouseButton]
}

struct MouseButtonControlMessage: Codable {
    let version: Int
    let type: String
    let sequence: Int
    let timestampMs: Double
    let button: MouseButton
    let action: InputAction
    let x: Double
    let y: Double
    let buttons: [MouseButton]
}

struct MouseWheelControlMessage: Codable {
    let version: Int
    let type: String
    let sequence: Int
    let timestampMs: Double
    let deltaX: Double
    let deltaY: Double
    let x: Double
    let y: Double
}

struct KeyboardKeyControlMessage: Codable {
    let version: Int
    let type: String
    let sequence: Int
    let timestampMs: Double
    let action: InputAction
    let code: String
    let key: String
    let modifiers: ModifierState
    let `repeat`: Bool
}

struct InputResetControlMessage: Codable {
    let version: Int
    let type: String
    let sequence: Int
    let timestampMs: Double
    let reason: String
}

struct StreamQualityControlMessage: Codable {
    let version: Int
    let type: String
    let sequence: Int
    let timestampMs: Double
    let settings: StreamQualitySettings
}

struct ClipboardSetControlMessage: Codable {
    let version: Int
    let type: String
    let sequence: Int
    let timestampMs: Double
    let source: String
    let text: String
}

struct ClipboardGetControlMessage: Codable {
    let version: Int
    let type: String
    let sequence: Int
    let timestampMs: Double
    let source: String
}

struct ClipboardValueControlMessage: Codable {
    let version: Int
    let type: String
    let sequence: Int
    let timestampMs: Double
    let source: String
    let replyToSequence: Int?
    let text: String
}

struct ClipboardErrorControlMessage: Codable {
    let version: Int
    let type: String
    let sequence: Int
    let timestampMs: Double
    let source: String
    let replyToSequence: Int?
    let code: String
    let message: String
}

enum ControlMessage {
    case mouseMove(MouseMoveControlMessage)
    case mouseButton(MouseButtonControlMessage)
    case mouseWheel(MouseWheelControlMessage)
    case keyboardKey(KeyboardKeyControlMessage)
    case reset(InputResetControlMessage)
    case streamQuality(StreamQualityControlMessage)
    case clipboardSet(ClipboardSetControlMessage)
    case clipboardGet(ClipboardGetControlMessage)
    case clipboardValue(ClipboardValueControlMessage)
    case clipboardError(ClipboardErrorControlMessage)

    var type: String {
        switch self {
        case .mouseMove(let message):
            message.type
        case .mouseButton(let message):
            message.type
        case .mouseWheel(let message):
            message.type
        case .keyboardKey(let message):
            message.type
        case .reset(let message):
            message.type
        case .streamQuality(let message):
            message.type
        case .clipboardSet(let message):
            message.type
        case .clipboardGet(let message):
            message.type
        case .clipboardValue(let message):
            message.type
        case .clipboardError(let message):
            message.type
        }
    }
}

enum ControlProtocol {
    static func decode(_ data: Data) throws -> ControlMessage {
        let envelope = try JSONDecoder().decode(ControlEnvelope.self, from: data)
        guard envelope.version == protocolVersion else {
            throw ControlProtocolError.unsupportedVersion
        }

        switch envelope.type {
        case "input.mouse.move":
            let message = try JSONDecoder().decode(MouseMoveControlMessage.self, from: data)
            try validateNormalized(message.x, message.y)
            return .mouseMove(message)
        case "input.mouse.button":
            let message = try JSONDecoder().decode(MouseButtonControlMessage.self, from: data)
            try validateNormalized(message.x, message.y)
            return .mouseButton(message)
        case "input.mouse.wheel":
            let message = try JSONDecoder().decode(MouseWheelControlMessage.self, from: data)
            try validateNormalized(message.x, message.y)
            return .mouseWheel(message)
        case "input.keyboard.key":
            return .keyboardKey(try JSONDecoder().decode(KeyboardKeyControlMessage.self, from: data))
        case "input.reset":
            return .reset(try JSONDecoder().decode(InputResetControlMessage.self, from: data))
        case "stream.quality.update":
            let message = try JSONDecoder().decode(StreamQualityControlMessage.self, from: data)
            try validateQuality(message.settings)
            return .streamQuality(message)
        case "clipboard.set":
            return .clipboardSet(try JSONDecoder().decode(ClipboardSetControlMessage.self, from: data))
        case "clipboard.get":
            return .clipboardGet(try JSONDecoder().decode(ClipboardGetControlMessage.self, from: data))
        case "clipboard.value":
            return .clipboardValue(try JSONDecoder().decode(ClipboardValueControlMessage.self, from: data))
        case "clipboard.error":
            return .clipboardError(try JSONDecoder().decode(ClipboardErrorControlMessage.self, from: data))
        default:
            throw ControlProtocolError.unsupportedType(envelope.type)
        }
    }

    private static func validateNormalized(_ x: Double, _ y: Double) throws {
        guard x >= 0, x <= 1, y >= 0, y <= 1 else {
            throw ControlProtocolError.invalidCoordinate
        }
    }

    private static func validateQuality(_ settings: StreamQualitySettings) throws {
        guard settings.maxBitrateBps >= 1_000_000, settings.maxBitrateBps <= 50_000_000 else {
            throw ControlProtocolError.invalidQuality
        }
    }
}

private struct ControlEnvelope: Codable {
    let version: Int
    let type: String
}

enum ControlProtocolError: LocalizedError {
    case invalidQuality
    case invalidCoordinate
    case unsupportedType(String)
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .invalidQuality:
            "Stream quality message is outside the supported bitrate range."
        case .invalidCoordinate:
            "Control message contains coordinates outside 0...1."
        case .unsupportedType(let type):
            "Unsupported control message type: \(type)."
        case .unsupportedVersion:
            "Unsupported control protocol version."
        }
    }
}
