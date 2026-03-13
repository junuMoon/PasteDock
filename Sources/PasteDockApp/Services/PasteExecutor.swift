import AppKit
import Foundation

enum PasteExecutionResult {
    case success
    case missingAccessibilityPermission
    case missingAutomationPermission
    case targetActivationFailed
    case systemEventsFailed
}

@MainActor
final class PasteExecutor {
    private let postCloseDelay: Duration = .milliseconds(80)
    private let activationPollInterval: Duration = .milliseconds(25)
    private let activationTimeout: Duration = .milliseconds(800)
    private let accessibilityService: AccessibilityService
    private let pasteScriptSource = """
    tell application "System Events"
        keystroke "v" using command down
    end tell
    """

    init(accessibilityService: AccessibilityService) {
        self.accessibilityService = accessibilityService
    }

    func paste(into app: NSRunningApplication?) async -> PasteExecutionResult {
        guard accessibilityService.isTrusted(prompt: false) else {
            return .missingAccessibilityPermission
        }

        let targetApplication = app ?? NSWorkspace.shared.frontmostApplication

        if let targetApplication,
           NSWorkspace.shared.frontmostApplication?.processIdentifier != targetApplication.processIdentifier {
            targetApplication.unhide()
            _ = targetApplication.activate(options: [.activateAllWindows])

            guard await waitForFrontmostApplication(processIdentifier: targetApplication.processIdentifier) else {
                return .targetActivationFailed
            }
        }

        try? await Task.sleep(for: postCloseDelay)

        return executePasteScript()
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

    private func executePasteScript() -> PasteExecutionResult {
        guard let script = NSAppleScript(source: pasteScriptSource) else {
            return .systemEventsFailed
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        guard let errorInfo else {
            return .success
        }

        let errorCode = errorInfo[NSAppleScript.errorNumber] as? Int
        if errorCode == -1743 {
            return .missingAutomationPermission
        }

        return .systemEventsFailed
    }
}
