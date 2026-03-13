import Foundation

enum SubmitMode: String, Codable, CaseIterable, Identifiable {
    case pasteNow
    case copyOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pasteNow:
            "Paste now"
        case .copyOnly:
            "Copy only"
        }
    }
}

struct AppSettings: Codable {
    var maxHistoryItems: Int = 150
    var retentionDays: Int = 30
    var capturePaused = false
    var excludedBundleIDs: [String] = []
    var shortcutPreset: KeyboardShortcutPreset = .controlS
    var defaultSubmitMode: SubmitMode = .pasteNow
}
