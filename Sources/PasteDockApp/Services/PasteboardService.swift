import AppKit
import Foundation

final class PasteboardService {
    private var pendingProgrammaticContentHash: String?

    func setItem(_ item: ClipboardItem) {
        pendingProgrammaticContentHash = item.contentHash
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.resolvedKind {
        case .text:
            pasteboard.setString(item.content, forType: .string)
        case .image:
            if let image = item.previewImage {
                pasteboard.writeObjects([image])
            }
        }
    }

    func consumeProgrammaticCopyIfNeeded(contentHash: String) -> Bool {
        guard pendingProgrammaticContentHash == contentHash else {
            return false
        }

        pendingProgrammaticContentHash = nil
        return true
    }
}
