import SwiftUI

struct QuickPanelView: View {
    @EnvironmentObject private var appModel: AppModel
    @FocusState private var isSearchFocused: Bool

    private static let absoluteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

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
        }
        .onChange(of: appModel.panelPresentationID) { _, _ in
            focusSearchField()
        }
        .onChange(of: appModel.searchQuery) { _, _ in
            appModel.handleSearchChange()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            TextField("Search clipboard history...", text: $appModel.searchQuery)
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
                List(selection: $appModel.selectedItemID) {
                    ForEach(appModel.filteredItems) { item in
                        ClipboardListItemView(
                            item: item,
                            isSelected: appModel.selectedItemID == item.id
                        )
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
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(minWidth: 380, idealWidth: 420, maxWidth: 460, maxHeight: .infinity)
    }

    private var rightPane: some View {
        ScrollView {
            if let item = appModel.selectedItem {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Preview")
                        .font(.headline)

                    Text(item.content)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )

                    VStack(alignment: .leading, spacing: 10) {
                        metadataRow("First copied", value: Self.absoluteFormatter.string(from: item.firstCopiedAt))
                        metadataRow("Last copied", value: Self.absoluteFormatter.string(from: item.lastCopiedAt))
                        metadataRow("Source app", value: item.sourceAppName ?? item.sourceBundleID ?? "Unknown")

                        if let lastPastedViaPasteDockAt = item.lastPastedViaPasteDockAt {
                            metadataRow(
                                "Last pasted via PasteDock",
                                value: Self.absoluteFormatter.string(from: lastPastedViaPasteDockAt)
                            )
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(24)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Preview")
                        .font(.headline)

                    Text("Select a clipboard item to inspect its full content and metadata.")
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyListState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No clipboard items yet")
                .font(.headline)

            Text("Copy text in any app and PasteDock will build your recent history automatically.")
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
            Text("Delete Remove item")
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

    private func focusSearchField() {
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }
}
