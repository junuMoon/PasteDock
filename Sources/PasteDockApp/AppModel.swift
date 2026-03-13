@preconcurrency import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var launchDate = Date()
    @Published private(set) var items: [ClipboardItem]
    @Published var settings: AppSettings
    @Published var searchQuery = ""
    @Published var selectedItemID: ClipboardItem.ID?
    @Published private(set) var accessibilityTrusted: Bool
    @Published private(set) var lastActionMessage: String?
    @Published private(set) var panelPresentationID = UUID()

    private let persistenceService = PersistenceService()
    private let pasteboardService = PasteboardService()
    private let clipboardMonitor = ClipboardMonitor()
    private let hotKeyService = HotKeyService()
    private let accessibilityService = AccessibilityService()
    private lazy var pasteExecutor = PasteExecutor(accessibilityService: accessibilityService)
    private lazy var quickPanelController = QuickPanelController(appModel: self)

    private var lastKnownExternalApplication: NSRunningApplication?
    private var workspaceObserver: NSObjectProtocol?

    private init() {
        let state = persistenceService.loadState()
        items = state.items
        settings = state.settings
        accessibilityTrusted = accessibilityService.isTrusted(prompt: false)

        migrateShortcutPreferenceIfNeeded()
        pruneAndSortItems()
        registerWorkspaceObserver()
        configureHotKey()
        configureClipboardMonitor()
        persistState()
    }

    var filteredItems: [ClipboardItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return items
        }

        let loweredQuery = query.localizedLowercase
        return items.filter { item in
            item.searchableText.localizedLowercase.contains(loweredQuery)
        }
    }

    var selectedItem: ClipboardItem? {
        guard let selectedItemID else {
            return filteredItems.first
        }

        return filteredItems.first { $0.id == selectedItemID } ?? filteredItems.first
    }

    var pauseCaptureTitle: String {
        settings.capturePaused ? "Resume Capture" : "Pause Capture"
    }

    var clipboardCountLabel: String {
        "\(items.count) item" + (items.count == 1 ? "" : "s")
    }

    var excludedAppsText: String {
        get {
            settings.excludedBundleIDs.joined(separator: "\n")
        }
        set {
            let bundleIDs = newValue
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            settings.excludedBundleIDs = bundleIDs
            persistState()
        }
    }

    func openQuickPanel() {
        accessibilityTrusted = accessibilityService.isTrusted(prompt: false)
        if let activeApp = NSWorkspace.shared.frontmostApplication,
           activeApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            lastKnownExternalApplication = activeApp
        }
        searchQuery = ""
        selectFirstFilteredItem()
        panelPresentationID = UUID()
        quickPanelController.show()
    }

    func toggleQuickPanel() {
        if quickPanelController.isVisible {
            closeQuickPanel()
        } else {
            openQuickPanel()
        }
    }

    func closeQuickPanel() {
        quickPanelController.close()
    }

    func moveSelection(offset: Int) {
        guard !filteredItems.isEmpty else {
            selectedItemID = nil
            return
        }

        guard let currentID = selectedItemID,
              let currentIndex = filteredItems.firstIndex(where: { $0.id == currentID }) else {
            selectFirstFilteredItem()
            return
        }

        let targetIndex = min(max(currentIndex + offset, 0), filteredItems.count - 1)
        selectedItemID = filteredItems[targetIndex].id
    }

    func selectItem(_ item: ClipboardItem) {
        selectedItemID = item.id
    }

    func submitSelectedItem(mode: SubmitMode) {
        guard let item = selectedItem else {
            NSSound.beep()
            return
        }

        let now = Date()
        pasteboardService.setItem(item)
        updateItemUsage(itemID: item.id, now: now, directPaste: mode == .pasteNow)
        closeQuickPanel()

        if mode == .pasteNow {
            let targetApp = lastKnownExternalApplication
            lastActionMessage = "Pasting..."

            Task { @MainActor [weak self] in
                guard let self else { return }

                let result = await pasteExecutor.paste(into: targetApp)
                accessibilityTrusted = accessibilityService.isTrusted(prompt: false)

                switch result {
                case .success:
                    lastActionMessage = "Pasted into the active app."
                case .missingAccessibilityPermission:
                    lastActionMessage = "Copied to clipboard. Grant Accessibility to enable Paste now."
                case .missingAutomationPermission:
                    lastActionMessage = "Copied to clipboard. Allow Automation for System Events to enable Paste now."
                case .targetActivationFailed:
                    lastActionMessage = "Copied to clipboard. Could not focus the target app."
                case .systemEventsFailed:
                    lastActionMessage = "Copied to clipboard. Press Cmd+V manually."
                }
            }
        } else {
            lastActionMessage = "Copied to clipboard."
        }
    }

    func deleteSelectedItem() {
        guard let selected = selectedItem else { return }
        items.removeAll { $0.id == selected.id }
        persistState()
        ensureValidSelection()
    }

    func clearHistory() {
        items.removeAll()
        persistState()
        ensureValidSelection()
    }

    func toggleCapturePaused() {
        settings.capturePaused.toggle()
        persistState()
    }

    func updateShortcutPreset(_ preset: KeyboardShortcutPreset) {
        settings.shortcutPreset = preset
        configureHotKey()
        persistState()
    }

    func updateHistoryLimit(_ value: Int) {
        settings.maxHistoryItems = max(10, value)
        pruneAndSortItems()
        persistState()
    }

    func updateRetentionDays(_ value: Int) {
        settings.retentionDays = max(1, value)
        pruneAndSortItems()
        persistState()
    }

    func updateDefaultSubmitMode(_ mode: SubmitMode) {
        settings.defaultSubmitMode = mode
        persistState()
    }

    func requestAccessibilityAccess() {
        accessibilityTrusted = accessibilityService.isTrusted(prompt: true)
    }

    func handleSearchChange() {
        ensureValidSelection()
    }

    func notePanelDidBecomeKey() {
        selectFirstFilteredItem()
    }

    private func configureHotKey() {
        hotKeyService.onHotKeyPressed = { [weak self] in
            Task { @MainActor in
                self?.toggleQuickPanel()
            }
        }
        hotKeyService.register(shortcut: settings.shortcutPreset)
    }

    private func configureClipboardMonitor() {
        clipboardMonitor.onChange = { [weak self] content in
            Task { @MainActor in
                self?.ingestClipboardChange(content: content)
            }
        }
        clipboardMonitor.start()
    }

    private func migrateShortcutPreferenceIfNeeded() {
        if settings.shortcutPreset == .commandShiftV {
            settings.shortcutPreset = .controlS
        }
    }

    private func ingestClipboardChange(content: ClipboardCapturedContent) {
        guard let normalized = normalizeClipboardContent(content) else {
            return
        }

        if pasteboardService.consumeProgrammaticCopyIfNeeded(contentHash: normalized.contentHash) {
            return
        }

        if settings.capturePaused {
            return
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication
        if isExcludedSourceApplication(sourceApp) {
            return
        }

        let now = Date()
        upsertItem(content: normalized, sourceApp: sourceApp, now: now)
    }

    private func normalizeClipboardContent(_ content: ClipboardCapturedContent) -> ClipboardCapturedContent? {
        switch content {
        case .text(let text):
            let normalized = text.trimmingCharacters(in: .newlines)
            guard !normalized.isEmpty else {
                return nil
            }

            return .text(normalized)
        case .image(let pngData, let width, let height):
            guard !pngData.isEmpty else {
                return nil
            }

            return .image(pngData: pngData, width: width, height: height)
        }
    }

    private func isExcludedSourceApplication(_ app: NSRunningApplication?) -> Bool {
        guard let app else {
            return false
        }

        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return true
        }

        guard let bundleID = app.bundleIdentifier else {
            return false
        }

        return settings.excludedBundleIDs.contains(bundleID)
    }

    private func upsertItem(content: ClipboardCapturedContent, sourceApp: NSRunningApplication?, now: Date) {
        let hash = content.contentHash

        if let index = items.firstIndex(where: { $0.contentHash == hash }) {
            apply(content: content, to: &items[index])
            items[index].lastCopiedAt = now
            items[index].sourceAppName = sourceApp?.localizedName ?? items[index].sourceAppName
            items[index].sourceBundleID = sourceApp?.bundleIdentifier ?? items[index].sourceBundleID
        } else {
            items.append(
                makeClipboardItem(
                    from: content,
                    sourceApp: sourceApp,
                    now: now,
                    hash: hash
                )
            )
        }

        pruneAndSortItems()
        persistState()
        ensureValidSelection()
    }

    private func updateItemUsage(itemID: ClipboardItem.ID, now: Date, directPaste: Bool) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        items[index].lastCopiedAt = now
        if directPaste {
            items[index].lastPastedViaPasteDockAt = now
        }

        pruneAndSortItems()
        persistState()
        selectedItemID = items.first?.id
    }

    private func makeClipboardItem(
        from content: ClipboardCapturedContent,
        sourceApp: NSRunningApplication?,
        now: Date,
        hash: String
    ) -> ClipboardItem {
        switch content {
        case .text(let text):
            return ClipboardItem(
                kind: .text,
                content: text,
                sourceAppName: sourceApp?.localizedName,
                sourceBundleID: sourceApp?.bundleIdentifier,
                firstCopiedAt: now,
                lastCopiedAt: now,
                lastPastedViaPasteDockAt: nil,
                isPinned: false,
                contentHash: hash
            )
        case .image(let pngData, let width, let height):
            return ClipboardItem(
                kind: .image,
                content: ClipboardItem.imagePlaceholder(width: width, height: height),
                imagePNGData: pngData,
                imageWidth: width,
                imageHeight: height,
                sourceAppName: sourceApp?.localizedName,
                sourceBundleID: sourceApp?.bundleIdentifier,
                firstCopiedAt: now,
                lastCopiedAt: now,
                lastPastedViaPasteDockAt: nil,
                isPinned: false,
                contentHash: hash
            )
        }
    }

    private func apply(content: ClipboardCapturedContent, to item: inout ClipboardItem) {
        switch content {
        case .text(let text):
            item.kind = .text
            item.content = text
            item.imagePNGData = nil
            item.imageWidth = nil
            item.imageHeight = nil
        case .image(let pngData, let width, let height):
            item.kind = .image
            item.content = ClipboardItem.imagePlaceholder(width: width, height: height)
            item.imagePNGData = pngData
            item.imageWidth = width
            item.imageHeight = height
        }
    }

    private func pruneAndSortItems() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -settings.retentionDays, to: Date()) ?? .distantPast
        items = items
            .filter { $0.lastCopiedAt >= cutoff }
            .sorted { $0.lastCopiedAt > $1.lastCopiedAt }

        if items.count > settings.maxHistoryItems {
            items = Array(items.prefix(settings.maxHistoryItems))
        }
    }

    private func ensureValidSelection() {
        guard !filteredItems.isEmpty else {
            selectedItemID = nil
            return
        }

        if let selectedItemID,
           filteredItems.contains(where: { $0.id == selectedItemID }) {
            return
        }

        selectFirstFilteredItem()
    }

    private func selectFirstFilteredItem() {
        selectedItemID = filteredItems.first?.id
    }

    private func persistState() {
        do {
            try persistenceService.saveState(items: items, settings: settings)
        } catch {
            lastActionMessage = "Failed to save clipboard history: \(error.localizedDescription)"
        }
    }

    private func registerWorkspaceObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                return
            }

            Task { @MainActor [weak self] in
                self?.lastKnownExternalApplication = app
            }
        }
    }
}
