import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("General") {
                Picker("Shortcut", selection: shortcutPresetBinding) {
                    ForEach(KeyboardShortcutPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }

                Toggle("Pause capture", isOn: capturePausedBinding)

                Stepper(value: historyLimitBinding, in: 10...1000, step: 10) {
                    settingsValueRow("Max history items", value: "\(appModel.settings.maxHistoryItems)")
                }

                Stepper(value: retentionDaysBinding, in: 1...365, step: 1) {
                    settingsValueRow("Retention days", value: "\(appModel.settings.retentionDays)")
                }
            }

            Section("Privacy") {
                VStack(alignment: .leading, spacing: 8) {
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
                }
                .padding(.vertical, 4)
            }

            Section("Accessibility") {
                settingsValueRow(
                    "Status",
                    value: appModel.accessibilityTrusted ? "Granted" : "Required for Paste now"
                )
                .foregroundStyle(appModel.accessibilityTrusted ? .green : .secondary)

                if !appModel.accessibilityTrusted {
                    Button("Request Accessibility Access") {
                        appModel.requestAccessibilityAccess()
                    }
                }

                Text("Paste now returns focus to the previous app and sends Paste. Without access, PasteDock falls back to copy only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Runtime") {
                settingsValueRow(
                    "Launched",
                    value: appModel.launchDate.formatted(date: .abbreviated, time: .standard)
                )
            }
        }
        .formStyle(.grouped)
        .padding(24)
    }

    private var excludedAppsBinding: Binding<String> {
        Binding(
            get: { appModel.excludedAppsText },
            set: { appModel.excludedAppsText = $0 }
        )
    }

    private var shortcutPresetBinding: Binding<KeyboardShortcutPreset> {
        Binding(
            get: { appModel.settings.shortcutPreset },
            set: { appModel.updateShortcutPreset($0) }
        )
    }

    private var capturePausedBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.capturePaused },
            set: { appModel.setCapturePaused($0) }
        )
    }

    private var historyLimitBinding: Binding<Int> {
        Binding(
            get: { appModel.settings.maxHistoryItems },
            set: { appModel.updateHistoryLimit($0) }
        )
    }

    private var retentionDaysBinding: Binding<Int> {
        Binding(
            get: { appModel.settings.retentionDays },
            set: { appModel.updateRetentionDays($0) }
        )
    }

    private func settingsValueRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
