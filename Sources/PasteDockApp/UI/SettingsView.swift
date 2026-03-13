import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sectionTitle("General")

                settingsRow(
                    title: "Shortcut",
                    value: appModel.settings.shortcutPreset.title,
                    buttonTitle: "Cycle"
                ) {
                    appModel.updateShortcutPreset(nextShortcutPreset)
                }

                settingsRow(
                    title: "Default submit",
                    value: appModel.settings.defaultSubmitMode.title,
                    buttonTitle: "Toggle"
                ) {
                    appModel.updateDefaultSubmitMode(nextSubmitMode)
                }

                settingsRow(
                    title: "Max history items",
                    value: "\(appModel.settings.maxHistoryItems)",
                    buttonTitle: "+10"
                ) {
                    appModel.updateHistoryLimit(appModel.settings.maxHistoryItems + 10)
                }

                settingsRow(
                    title: "Retention days",
                    value: "\(appModel.settings.retentionDays)",
                    buttonTitle: "+1"
                ) {
                    appModel.updateRetentionDays(appModel.settings.retentionDays + 1)
                }

                Button(appModel.pauseCaptureTitle) {
                    appModel.toggleCapturePaused()
                }

                Divider()

                sectionTitle("Privacy")
                Text("Excluded app bundle identifiers")
                    .font(.system(size: 12, weight: .semibold))
                TextEditor(text: excludedAppsBinding)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                Text("One bundle identifier per line. Clipboard changes from these apps will not be stored.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Divider()

                sectionTitle("Accessibility")
                Text(appModel.accessibilityTrusted ? "Access granted" : "Required for Paste now")
                    .foregroundStyle(appModel.accessibilityTrusted ? .green : .secondary)

                if !appModel.accessibilityTrusted {
                    Button("Request Accessibility Access") {
                        appModel.requestAccessibilityAccess()
                    }
                }

                Text("Paste now requires PasteDock to activate the previous app and send Cmd+V. Without access, the app falls back to copy-only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Divider()

                sectionTitle("Runtime")
                Text("Launched \(appModel.launchDate.formatted(date: .abbreviated, time: .standard))")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }

    private var excludedAppsBinding: Binding<String> {
        Binding(
            get: { appModel.excludedAppsText },
            set: { appModel.excludedAppsText = $0 }
        )
    }

    private var nextShortcutPreset: KeyboardShortcutPreset {
        let allCases = KeyboardShortcutPreset.allCases
        guard let index = allCases.firstIndex(of: appModel.settings.shortcutPreset) else {
            return allCases[0]
        }

        return allCases[(index + 1) % allCases.count]
    }

    private var nextSubmitMode: SubmitMode {
        switch appModel.settings.defaultSubmitMode {
        case .pasteNow:
            .copyOnly
        case .copyOnly:
            .pasteNow
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
    }

    private func settingsRow(
        title: String,
        value: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
            Button(buttonTitle, action: action)
        }
    }
}
