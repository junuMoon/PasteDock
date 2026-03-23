import SwiftUI

struct QuickPanelView: View {
    @EnvironmentObject private var appModel: AppModel
    @FocusState private var isSearchFocused: Bool
    @State private var pendingScrollTask: Task<Void, Never>?
    @State private var pendingPreviewTask: Task<Void, Never>?
    @State private var previewedItemID: ClipboardItem.ID?

    private let previewUpdateDelay: Duration = .milliseconds(75)

    private static let absoluteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var searchQueryBinding: Binding<String> {
        Binding(
            get: { appModel.searchQuery },
            set: { appModel.updateSearchQuery($0) }
        )
    }

    private var previewItem: ClipboardItem? {
        guard let previewedItemID else {
            return nil
        }

        return appModel.items.first(where: { $0.id == previewedItemID })
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 980, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            focusSearchField()
            syncPreviewSelection(immediately: true)
        }
        .onDisappear {
            pendingScrollTask?.cancel()
            pendingPreviewTask?.cancel()
        }
        .onChange(of: appModel.panelPresentationID) { _, _ in
            focusSearchField()
            syncPreviewSelection(immediately: true)
        }
        .onChange(of: appModel.selectedItemID) { _, _ in
            syncPreviewSelection(immediately: false)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            TextField("Search clipboard history...", text: searchQueryBinding)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)

            if appModel.settings.capturePaused {
                Label("Capture Paused", systemImage: "pause.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 12, weight: .semibold))
            }

            Text(appModel.clipboardCountLabel)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var content: some View {
        HStack(spacing: 0) {
            leftPane
            Divider()
            rightPane
        }
    }

    private var leftPane: some View {
        Group {
            if appModel.filteredItems.isEmpty {
                emptyListState
            } else {
                ScrollViewReader { proxy in
                    List(selection: $appModel.selectedItemID) {
                        ForEach(appModel.filteredItems) { item in
                            ClipboardListItemView(
                                item: item,
                                isSelected: appModel.selectedItemID == item.id
                            )
                            .id(item.id)
                            .tag(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                appModel.selectItem(item)
                            }
                            .onTapGesture(count: 2) {
                                appModel.selectItem(item)
                                appModel.submitSelectedItem(mode: .pasteNow)
                            }
                        }
                    }
                    .onAppear {
                        scheduleScrollSelection(into: proxy)
                    }
                    .onChange(of: appModel.selectedItemID) { _, _ in
                        scheduleScrollSelection(into: proxy)
                    }
                    .onChange(of: appModel.panelPresentationID) { _, _ in
                        scheduleScrollSelection(into: proxy)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(minWidth: 380, idealWidth: 420, maxWidth: 460, maxHeight: .infinity)
    }

    private var rightPane: some View {
        Group {
            if let item = previewItem {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Preview")
                        .font(.headline)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if item.isImage, let image = appModel.previewImage(for: item) {
                                imagePreview(image)
                            } else {
                                textPreview(item.content)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 10) {
                        metadataRow("Content type", value: item.contentTypeLabel)
                        metadataRow("First copied", value: Self.absoluteFormatter.string(from: item.firstCopiedAt))
                        metadataRow("Last copied", value: Self.absoluteFormatter.string(from: item.lastCopiedAt))
                        metadataRow("Source app", value: item.sourceAppName ?? item.sourceBundleID ?? "Unknown")

                        if let imageDimensionText = item.imageDimensionText {
                            metadataRow("Dimensions", value: imageDimensionText)
                        }

                        if let lastPastedViaPasteDockAt = item.lastPastedViaPasteDockAt {
                            metadataRow(
                                "Last pasted via PasteDock",
                                value: Self.absoluteFormatter.string(from: lastPastedViaPasteDockAt)
                            )
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Preview")
                        .font(.headline)

                    Text("Select a clipboard item to inspect its full content and metadata.")
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyListState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No clipboard items yet")
                .font(.headline)

            Text("Copy text or an image in any app and PasteDock will build your recent history automatically.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private var footer: some View {
        HStack(spacing: 18) {
            Text("Enter Paste now")
            Text("Cmd+Enter Copy only")
            Text("Cmd+Delete Remove item")
            Spacer()
            if let lastActionMessage = appModel.lastActionMessage {
                Text(lastActionMessage)
                    .foregroundStyle(.secondary)
            }
            Text("Esc Close")
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private func metadataRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 170, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .textSelection(.enabled)
        }
    }

    private func textPreview(_ content: String) -> some View {
        Text(content)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
    }

    private func imagePreview(_ image: NSImage) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .textBackgroundColor))

            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260, idealHeight: 360)
    }

    private func focusSearchField() {
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private func scheduleScrollSelection(into proxy: ScrollViewProxy) {
        guard let selectedItemID = appModel.selectedItemID else {
            return
        }

        pendingScrollTask?.cancel()
        pendingScrollTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }

            proxy.scrollTo(selectedItemID, anchor: .center)
        }
    }

    private func syncPreviewSelection(immediately: Bool) {
        let selectedItemID = appModel.selectedItemID

        pendingPreviewTask?.cancel()
        if immediately || selectedItemID == nil {
            previewedItemID = selectedItemID
            return
        }

        pendingPreviewTask = Task { @MainActor in
            do {
                try await Task.sleep(for: previewUpdateDelay)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            previewedItemID = appModel.selectedItemID
        }
    }
}
