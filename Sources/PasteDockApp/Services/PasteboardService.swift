import AppKit
import Foundation

final class PasteboardService {
    private var pendingProgrammaticContent: String?

    func setString(_ value: String) {
        pendingProgrammaticContent = value
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }

    func consumeProgrammaticCopyIfNeeded(content: String) -> Bool {
        guard pendingProgrammaticContent == content else {
            return false
        }

        pendingProgrammaticContent = nil
        return true
    }
}
