import AppKit
import ApplicationServices
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

        if let targetApplication,
           executeAccessibilityPaste(in: targetApplication) == .success {
            return .success
        }

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

    private func executeAccessibilityPaste(in app: NSRunningApplication) -> PasteExecutionResult {
        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, 1.0)

        guard let menuBar = copyElementAttribute(kAXMenuBarAttribute as CFString, from: applicationElement) else {
            return .systemEventsFailed
        }

        guard let pasteMenuItem = findPasteMenuItem(in: menuBar) else {
            return .systemEventsFailed
        }

        let result = AXUIElementPerformAction(pasteMenuItem, kAXPressAction as CFString)
        return result == .success ? .success : .systemEventsFailed
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

    private func findPasteMenuItem(in element: AXUIElement) -> AXUIElement? {
        if isPasteMenuItem(element) {
            return element
        }

        for child in copyChildrenAttribute(from: element) {
            if let match = findPasteMenuItem(in: child) {
                return match
            }
        }

        return nil
    }

    private func isPasteMenuItem(_ element: AXUIElement) -> Bool {
        guard let commandCharacter = copyStringAttribute(kAXMenuItemCmdCharAttribute as CFString, from: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              commandCharacter == "v" else {
            return false
        }

        let modifiers = copyUInt32Attribute(kAXMenuItemCmdModifiersAttribute as CFString, from: element) ?? 0
        return modifiers == 0
    }

    private func copyElementAttribute(_ attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func copyChildrenAttribute(from element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard result == .success,
              let array = value as? [Any] else {
            return []
        }

        return array.compactMap { item in
            guard CFGetTypeID(item as CFTypeRef) == AXUIElementGetTypeID() else {
                return nil
            }

            return unsafeDowncast(item as AnyObject, to: AXUIElement.self)
        }
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }

        return value as? String
    }

    private func copyUInt32Attribute(_ attribute: CFString, from element: AXUIElement) -> UInt32? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success,
              let number = value as? NSNumber else {
            return nil
        }

        return number.uint32Value
    }
}
