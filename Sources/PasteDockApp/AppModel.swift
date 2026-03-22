@preconcurrency import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var launchDate = Date()
    @Published private(set) var items: [ClipboardItem]
    @Published private(set) var filteredItems: [ClipboardItem] = []
    @Published var settings: AppSettings
    @Published var searchQuery = ""
    @Published var selectedItemID: ClipboardItem.ID?
    @Published private(set) var selectedItem: ClipboardItem?
    @Published private(set) var accessibilityTrusted: Bool
    @Published private(set) var lastActionMessage: String?
    @Published private(set) var panelPresentationID = UUID()

    private let persistenceDebounce: Duration = .milliseconds(400)
    private let persistenceService = PersistenceService()
    private let pasteboardService = PasteboardService()
    private let clipboardMonitor = ClipboardMonitor()
    private let hotKeyService = HotKeyService()
    private let accessibilityService = AccessibilityService()
    private let previewImageCache = NSCache<NSString, NSImage>()
    private lazy var pasteExecutor = PasteExecutor(accessibilityService: accessibilityService)
    private lazy var quickPanelController = QuickPanelController(appModel: self)

    private var lastKnownExternalApplication: NSRunningApplication?
    private var normalizedSearchableTextByID: [ClipboardItem.ID: String] = [:]
    private var pendingPersistenceTask: Task<Void, Never>?
    private var workspaceObserver: NSObjectProtocol?

    private init() {
        let state = persistenceService.loadState()
        items = state.items
        settings = state.settings
        accessibilityTrusted = accessibilityService.isTrusted(prompt: false)

        migrateShortcutPreferenceIfNeeded()
        pruneAndSortItems()
        rebuildSearchIndex()
        refreshDerivedState(preserveSelection: false)
        registerWorkspaceObserver()
        configureHotKey()
        configureClipboardMonitor()
        persistStateImmediately()
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
            schedulePersistState()
        }
    }

    func openQuickPanel() {
        accessibilityTrusted = accessibilityService.isTrusted(prompt: false)
        if let activeApp = NSWorkspace.shared.frontmostApplication,
           activeApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            lastKnownExternalApplication = activeApp
        }
        lastActionMessage = nil
        searchQuery = ""
        refreshDerivedState(preserveSelection: false)
        panelPresentationID = UUID()
        quickPanelController.show()
    }

    func toggleQuickPanel() {
        if quickPanelController.isVisible {
            closeQuickPanel(restoreFocus: true)
        } else {
            openQuickPanel()
        }
    }

    func closeQuickPanel(restoreFocus: Bool = false) {
        let targetApplication = restoreFocus ? lastKnownExternalApplication : nil
        quickPanelController.close()

        guard let targetApplication,
              targetApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !targetApplication.isTerminated else {
            return
        }

        Task { @MainActor in
            await Task.yield()
            targetApplication.unhide()
            _ = targetApplication.activate(options: [.activateAllWindows])
        }
    }

    func moveSelection(offset: Int) {
        guard !filteredItems.isEmpty else {
            setSelectedItemID(nil)
            return
        }

        guard let currentID = selectedItemID,
              let currentIndex = filteredItems.firstIndex(where: { $0.id == currentID }) else {
            selectFirstFilteredItem()
            return
        }

        let targetIndex = min(max(currentIndex + offset, 0), filteredItems.count - 1)
        guard targetIndex != currentIndex else {
            return
        }

        setSelectedItemID(filteredItems[targetIndex].id)
    }

    func selectItem(_ item: ClipboardItem) {
        setSelectedItemID(item.id)
    }

    func submitSelectedItem(mode: SubmitMode) {
        guard let item = selectedItem else {
            NSSound.beep()
            return
        }

        let now = Date()
        pasteboardService.setItem(item)
        updateItemUsage(itemID: item.id, now: now, directPaste: mode == .pasteNow)
        closeQuickPanel(restoreFocus: mode == .copyOnly)

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
        schedulePersistState()
        syncDerivedStateAfterItemMutation()
    }

    func clearHistory() {
        items.removeAll()
        schedulePersistState()
        syncDerivedStateAfterItemMutation()
    }

    func toggleCapturePaused() {
        setCapturePaused(!settings.capturePaused)
    }

    func setCapturePaused(_ isPaused: Bool) {
        settings.capturePaused = isPaused
        schedulePersistState()
    }

    func updateShortcutPreset(_ preset: KeyboardShortcutPreset) {
        settings.shortcutPreset = preset
        configureHotKey()
        schedulePersistState()
    }

    func updateHistoryLimit(_ value: Int) {
        settings.maxHistoryItems = max(10, value)
        pruneAndSortItems()
        syncDerivedStateAfterItemMutation()
        schedulePersistState()
    }

    func updateRetentionDays(_ value: Int) {
        settings.retentionDays = max(1, value)
        pruneAndSortItems()
        syncDerivedStateAfterItemMutation()
        schedulePersistState()
    }

    func requestAccessibilityAccess() {
        accessibilityTrusted = accessibilityService.isTrusted(prompt: true)
    }

    func updateSearchQuery(_ query: String) {
        searchQuery = query
        refreshDerivedState(preserveSelection: true)
    }

    func handleSearchChange() {
        refreshDerivedState(preserveSelection: true)
    }

    func notePanelDidBecomeKey() {
        refreshDerivedState(preserveSelection: false)
    }

    func previewImage(for item: ClipboardItem) -> NSImage? {
        guard let imagePNGData = item.imagePNGData else {
            return nil
        }

        let cacheKey = item.contentHash as NSString
        if let cachedImage = previewImageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let image = NSImage(data: imagePNGData) else {
            return nil
        }

        previewImageCache.setObject(image, forKey: cacheKey)
        return image
    }

    deinit {
        pendingPersistenceTask?.cancel()
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
    }

    func flushPersistence() {
        pendingPersistenceTask?.cancel()
        pendingPersistenceTask = nil
        persistStateImmediately()
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
        schedulePersistState()
        syncDerivedStateAfterItemMutation()
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
        schedulePersistState()
        syncDerivedStateAfterItemMutation()
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

    private func syncDerivedStateAfterItemMutation() {
        rebuildSearchIndex()
        refreshDerivedState(preserveSelection: true)
    }

    private func rebuildSearchIndex() {
        normalizedSearchableTextByID = Dictionary(
            uniqueKeysWithValues: items.map { item in
                (item.id, Self.makeNormalizedSearchText(for: item))
            }
        )
    }

    private func refreshDerivedState(preserveSelection: Bool) {
        filteredItems = matchingItems(for: searchQuery)

        let nextSelectedID: ClipboardItem.ID?
        if preserveSelection,
           let selectedItemID,
           filteredItems.contains(where: { $0.id == selectedItemID }) {
            nextSelectedID = selectedItemID
        } else {
            nextSelectedID = filteredItems.first?.id
        }

        setSelectedItemID(nextSelectedID)
    }

    private func matchingItems(for query: String) -> [ClipboardItem] {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedQuery.isEmpty else {
            return items
        }

        return items.filter { item in
            normalizedSearchableTextByID[item.id, default: ""].contains(normalizedQuery)
        }
    }

    private static func makeNormalizedSearchText(for item: ClipboardItem) -> String {
        item.searchableText.lowercased()
    }

    private func setSelectedItemID(_ id: ClipboardItem.ID?) {
        let nextSelectedItem = id.flatMap { selectedID in
            filteredItems.first(where: { $0.id == selectedID })
        } ?? filteredItems.first

        guard selectedItemID != id || selectedItem != nextSelectedItem else {
            return
        }

        selectedItemID = id
        selectedItem = nextSelectedItem
    }

    private func ensureValidSelection() {
        guard !filteredItems.isEmpty else {
            setSelectedItemID(nil)
            return
        }

        if let selectedItemID,
           filteredItems.contains(where: { $0.id == selectedItemID }) {
            return
        }

        selectFirstFilteredItem()
    }

    private func selectFirstFilteredItem() {
        setSelectedItemID(filteredItems.first?.id)
    }

    private func schedulePersistState() {
        let itemsSnapshot = items
        let settingsSnapshot = settings
        let persistenceDebounce = self.persistenceDebounce

        pendingPersistenceTask?.cancel()
        pendingPersistenceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: persistenceDebounce)
            } catch {
                return
            }

            self?.persistStateInBackground(items: itemsSnapshot, settings: settingsSnapshot)
        }
    }

    private func persistStateImmediately() {
        do {
            try persistenceService.saveState(items: items, settings: settings)
        } catch {
            lastActionMessage = "Failed to save clipboard history: \(error.localizedDescription)"
        }
    }

    private func persistStateInBackground(items: [ClipboardItem], settings: AppSettings) {
        persistenceService.saveStateAsync(items: items, settings: settings) { [weak self] result in
            guard case .failure(let error) = result else {
                return
            }

            Task { @MainActor [weak self] in
                self?.lastActionMessage = "Failed to save clipboard history: \(error.localizedDescription)"
            }
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
