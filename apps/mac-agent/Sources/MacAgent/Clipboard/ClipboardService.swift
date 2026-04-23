import AppKit
import Foundation

enum ClipboardReadResult {
    case empty
    case nonText
    case text(String)
}

final class ClipboardService {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func readText() throws -> ClipboardReadResult {
        if let text = pasteboard.string(forType: .string) {
            return .text(text)
        }

        let items = pasteboard.pasteboardItems ?? []
        if items.isEmpty {
            return .empty
        }

        return .nonText
    }

    func setText(_ text: String) throws {
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw ClipboardError.writeFailed
        }
    }
}

enum ClipboardError: LocalizedError {
    case empty
    case nonText
    case readFailed
    case writeFailed

    var code: String {
        switch self {
        case .empty:
            "empty"
        case .nonText:
            "non_text"
        case .readFailed:
            "read_failed"
        case .writeFailed:
            "write_failed"
        }
    }

    var errorDescription: String? {
        switch self {
        case .empty:
            "The Mac clipboard is empty."
        case .nonText:
            "The Mac clipboard does not currently contain plain text."
        case .readFailed:
            "Failed to read the Mac clipboard."
        case .writeFailed:
            "Failed to write plain text to the Mac clipboard."
        }
    }
}
