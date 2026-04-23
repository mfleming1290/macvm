import Foundation

struct ControlDiagnostics: Codable {
    var channelState: String
    var accessibilityAllowed: Bool
    var receivedMessages: Int
    var injectedEvents: Int
    var resetCount: Int
    var clipboardReads: Int
    var clipboardWrites: Int
    var lastClipboardTextLength: Int?
    var pressedKeys: Int
    var pressedButtons: Int
    var lastMessageType: String?
    var lastMappedX: Double?
    var lastMappedY: Double?
    var lastError: String?

    enum CodingKeys: String, CodingKey {
        case channelState
        case accessibilityAllowed
        case receivedMessages
        case injectedEvents
        case resetCount
        case clipboardReads
        case clipboardWrites
        case lastClipboardTextLength
        case pressedKeys
        case pressedButtons
        case lastMessageType
        case lastMappedX
        case lastMappedY
        case lastError
    }

    static let empty = ControlDiagnostics(
        channelState: "none",
        accessibilityAllowed: AccessibilityPermission.isGranted,
        receivedMessages: 0,
        injectedEvents: 0,
        resetCount: 0,
        clipboardReads: 0,
        clipboardWrites: 0,
        lastClipboardTextLength: nil,
        pressedKeys: 0,
        pressedButtons: 0,
        lastMessageType: nil,
        lastMappedX: nil,
        lastMappedY: nil,
        lastError: nil
    )

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(channelState, forKey: .channelState)
        try container.encode(accessibilityAllowed, forKey: .accessibilityAllowed)
        try container.encode(receivedMessages, forKey: .receivedMessages)
        try container.encode(injectedEvents, forKey: .injectedEvents)
        try container.encode(resetCount, forKey: .resetCount)
        try container.encode(clipboardReads, forKey: .clipboardReads)
        try container.encode(clipboardWrites, forKey: .clipboardWrites)
        try container.encode(lastClipboardTextLength, forKey: .lastClipboardTextLength)
        try container.encode(pressedKeys, forKey: .pressedKeys)
        try container.encode(pressedButtons, forKey: .pressedButtons)
        try container.encode(lastMessageType, forKey: .lastMessageType)
        try container.encode(lastMappedX, forKey: .lastMappedX)
        try container.encode(lastMappedY, forKey: .lastMappedY)
        try container.encode(lastError, forKey: .lastError)
    }
}
