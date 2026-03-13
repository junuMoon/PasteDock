@preconcurrency import AppKit
import SwiftUI

@MainActor
final class QuickPanelController: NSWindowController, NSWindowDelegate {
    private unowned let appModel: AppModel
    private let panel: NSPanel
    private let hostingView: NSHostingView<AnyView>
    private var keyMonitor: Any?

    init(appModel: AppModel) {
        self.appModel = appModel
        self.hostingView = NSHostingView(rootView: AnyView(QuickPanelView().environmentObject(appModel)))

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 560),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .modalPanel
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = hostingView
        self.panel = panel

        super.init(window: panel)

        panel.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func show() {
        positionPanel()
        appModel.notePanelDidBecomeKey()
        installKeyMonitorIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    override func close() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func positionPanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let originX = visibleFrame.midX - panel.frame.width / 2
        let originY = visibleFrame.maxY - panel.frame.height - 80
        panel.setFrameOrigin(NSPoint(x: originX, y: max(originY, visibleFrame.minY + 40)))
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else {
            return
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, event.window == self.panel else {
                return event
            }

            if self.handleKeyDown(event) {
                return nil
            }

            return event
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch event.keyCode {
        case 125:
            appModel.moveSelection(offset: 1)
            return true
        case 126:
            appModel.moveSelection(offset: -1)
            return true
        case 53:
            appModel.closeQuickPanel()
            return true
        case 51:
            appModel.deleteSelectedItem()
            return true
        case 36, 76:
            if modifiers.contains(.command) {
                appModel.submitSelectedItem(mode: .copyOnly)
            } else {
                appModel.submitSelectedItem(mode: .pasteNow)
            }
            return true
        default:
            return false
        }
    }
}
