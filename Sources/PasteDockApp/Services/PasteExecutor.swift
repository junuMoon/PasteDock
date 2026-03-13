import AppKit
import Foundation

@MainActor
final class PasteExecutor {
    private let activationPollInterval: Duration = .milliseconds(25)
    private let activationTimeout: Duration = .milliseconds(400)
    private let accessibilityService: AccessibilityService

    init(accessibilityService: AccessibilityService) {
        self.accessibilityService = accessibilityService
    }

    func paste(into app: NSRunningApplication?) async -> Bool {
        guard let app else {
            return false
        }

        guard accessibilityService.isTrusted(prompt: false) else {
            return false
        }

        app.unhide()
        _ = app.activate(options: [.activateAllWindows])
        _ = await waitForFrontmostApplication(processIdentifier: app.processIdentifier)

        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(app.processIdentifier)
        keyUp.postToPid(app.processIdentifier)

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
