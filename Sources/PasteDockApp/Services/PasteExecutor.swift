import AppKit
import Foundation

@MainActor
final class PasteExecutor {
    private let pasteKeyInterval: Duration = .milliseconds(12)
    private let postCloseDelay: Duration = .milliseconds(70)
    private let activationPollInterval: Duration = .milliseconds(25)
    private let activationTimeout: Duration = .milliseconds(800)
    private let accessibilityService: AccessibilityService

    init(accessibilityService: AccessibilityService) {
        self.accessibilityService = accessibilityService
    }

    func paste(into app: NSRunningApplication?) async -> Bool {
        guard accessibilityService.isTrusted(prompt: false) else {
            return false
        }

        if let app,
           NSWorkspace.shared.frontmostApplication?.processIdentifier != app.processIdentifier {
            app.unhide()
            _ = app.activate(options: [.activateAllWindows])

            guard await waitForFrontmostApplication(processIdentifier: app.processIdentifier) else {
                return false
            }
        }

        try? await Task.sleep(for: postCloseDelay)

        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        try? await Task.sleep(for: pasteKeyInterval)
        keyUp.post(tap: .cghidEventTap)

        return true
    }

    private func waitForFrontmostApplication(processIdentifier: pid_t) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: activationTimeout)

        while clock.now < deadline {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == processIdentifier {
                return true
            }

            try? await Task.sleep(for: activationPollInterval)
        }

        return NSWorkspace.shared.frontmostApplication?.processIdentifier == processIdentifier
    }
}
