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

struct StreamStatsReportControlMessage: Codable {
    let version: Int
    let type: String
    let sequence: Int
    let timestampMs: Double
    let stats: StreamClientStats
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
    case streamStatsReport(StreamStatsReportControlMessage)

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
        case .streamStatsReport(let message):
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
            let message = try JSONDecoder().decode(InputResetControlMessage.self, from: data)
            try validateResetReason(message.reason)
            return .reset(message)
        case "stream.quality.update":
            let message = try JSONDecoder().decode(StreamQualityControlMessage.self, from: data)
            try validateQuality(message.settings)
            return .streamQuality(message)
        case "clipboard.set":
            let message = try JSONDecoder().decode(ClipboardSetControlMessage.self, from: data)
            try validateClipboardSource(message.source)
            return .clipboardSet(message)
        case "clipboard.get":
            let message = try JSONDecoder().decode(ClipboardGetControlMessage.self, from: data)
            try validateClipboardSource(message.source)
            return .clipboardGet(message)
        case "clipboard.value":
            let message = try JSONDecoder().decode(ClipboardValueControlMessage.self, from: data)
            try validateClipboardSource(message.source)
            return .clipboardValue(message)
        case "clipboard.error":
            let message = try JSONDecoder().decode(ClipboardErrorControlMessage.self, from: data)
            try validateClipboardSource(message.source)
            try validateClipboardErrorCode(message.code)
            return .clipboardError(message)
        case "stream.stats.report":
            return .streamStatsReport(try JSONDecoder().decode(StreamStatsReportControlMessage.self, from: data))
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
        guard settings.maxBitrateBps >= 1_000_000, settings.maxBitrateBps <= 100_000_000 else {
            throw ControlProtocolError.invalidQuality
        }

        guard [30, 45, 60].contains(settings.framesPerSecond) else {
            throw ControlProtocolError.invalidQuality
        }

        guard settings.hasSupportedResolutionPreset else {
            throw ControlProtocolError.invalidQuality
        }
    }

    private static func validateClipboardSource(_ source: String) throws {
        guard source == "browser" || source == "agent" else {
            throw ControlProtocolError.invalidClipboardSource
        }
    }

    private static func validateClipboardErrorCode(_ code: String) throws {
        guard code == "empty" || code == "non_text" || code == "read_failed" || code == "write_failed" else {
            throw ControlProtocolError.invalidClipboardErrorCode
        }
    }

    private static func validateResetReason(_ reason: String) throws {
        guard reason == "blur" ||
            reason == "disconnect" ||
            reason == "reconnect" ||
            reason == "visibilitychange" ||
            reason == "manual" else {
            throw ControlProtocolError.invalidResetReason
        }
    }
}

private struct ControlEnvelope: Codable {
    let version: Int
    let type: String
}

enum ControlProtocolError: LocalizedError {
    case invalidClipboardErrorCode
    case invalidClipboardSource
    case invalidQuality
    case invalidCoordinate
    case invalidResetReason
    case unsupportedType(String)
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .invalidClipboardErrorCode:
            "Clipboard error message contains an unsupported error code."
        case .invalidClipboardSource:
            "Clipboard message contains an unsupported source."
        case .invalidQuality:
            "Stream quality message is outside the supported bitrate range."
        case .invalidCoordinate:
            "Control message contains coordinates outside 0...1."
        case .invalidResetReason:
            "Reset message contains an unsupported reason."
        case .unsupportedType(let type):
            "Unsupported control message type: \(type)."
        case .unsupportedVersion:
            "Unsupported control protocol version."
        }
    }
}
