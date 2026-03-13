import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

@_silgen_name("AXUIElementPostKeyboardEvent")
private func axPostKeyboardEvent(
    _ application: AXUIElement,
    _ keyChar: CGCharCode,
    _ virtualKey: CGKeyCode,
    _ keyDown: DarwinBoolean
) -> AXError

@MainActor
final class PasteExecutor {
    private let commandKeyCode = CGKeyCode(kVK_Command)
    private let pasteKeyCode = CGKeyCode(kVK_ANSI_V)
    private let pasteCharacter = CGCharCode(UnicodeScalar("v").value)
    private let keyInterval: Duration = .milliseconds(12)
    private let postCloseDelay: Duration = .milliseconds(80)
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

        let targetApplication = app ?? NSWorkspace.shared.frontmostApplication

        if let targetApplication,
           NSWorkspace.shared.frontmostApplication?.processIdentifier != targetApplication.processIdentifier {
            targetApplication.unhide()
            _ = targetApplication.activate(options: [.activateAllWindows])

            guard await waitForFrontmostApplication(processIdentifier: targetApplication.processIdentifier) else {
                return false
            }
        }

        try? await Task.sleep(for: postCloseDelay)

        let targetElement = targetApplication
            .map { AXUIElementCreateApplication($0.processIdentifier) }
            ?? AXUIElementCreateSystemWide()

        AXUIElementSetMessagingTimeout(targetElement, 1.0)
        return await postPasteShortcut(to: targetElement)
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

    private func postPasteShortcut(to targetElement: AXUIElement) async -> Bool {
        let resultSequence = [
            axPostKeyboardEvent(targetElement, 0, commandKeyCode, true),
            axPostKeyboardEvent(targetElement, pasteCharacter, pasteKeyCode, true)
        ]

        guard resultSequence.allSatisfy({ $0 == .success }) else {
            _ = axPostKeyboardEvent(targetElement, 0, commandKeyCode, false)
            return false
        }

        try? await Task.sleep(for: keyInterval)

        let releaseSequence = [
            axPostKeyboardEvent(targetElement, pasteCharacter, pasteKeyCode, false),
            axPostKeyboardEvent(targetElement, 0, commandKeyCode, false)
        ]

        return releaseSequence.allSatisfy { $0 == .success }
    }
}
