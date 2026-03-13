import Carbon.HIToolbox
import Foundation

enum KeyboardShortcutPreset: String, Codable, CaseIterable, Identifiable {
    case commandShiftV
    case commandOptionV
    case commandShiftSpace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commandShiftV:
            "Cmd+Shift+V"
        case .commandOptionV:
            "Cmd+Option+V"
        case .commandShiftSpace:
            "Cmd+Shift+Space"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .commandShiftV, .commandOptionV:
            9
        case .commandShiftSpace:
            49
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .commandShiftV:
            UInt32(cmdKey | shiftKey)
        case .commandOptionV:
            UInt32(cmdKey | optionKey)
        case .commandShiftSpace:
            UInt32(cmdKey | shiftKey)
        }
    }
}
