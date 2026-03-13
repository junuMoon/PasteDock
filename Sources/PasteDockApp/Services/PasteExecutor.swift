import AppKit
import Foundation

final class PasteExecutor {
    private let accessibilityService: AccessibilityService

    init(accessibilityService: AccessibilityService) {
        self.accessibilityService = accessibilityService
    }

    func paste(into app: NSRunningApplication?) -> Bool {
        guard let app else {
            return false
        }

        guard accessibilityService.isTrusted(prompt: false) || accessibilityService.isTrusted(prompt: true) else {
            return false
        }

        _ = app.activate()
        Thread.sleep(forTimeInterval: 0.12)

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        return true
    }
}
