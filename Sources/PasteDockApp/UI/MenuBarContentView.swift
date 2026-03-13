import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PasteDock")
                .font(.headline)

            Text(appModel.clipboardCountLabel)
                .foregroundStyle(.secondary)

            Divider()

            Button("Open Quick Panel") {
                appModel.openQuickPanel()
            }

            Button(appModel.pauseCaptureTitle) {
                appModel.toggleCapturePaused()
            }

            Button("Clear History") {
                appModel.clearHistory()
            }

            Divider()

            if !appModel.accessibilityTrusted {
                Button("Request Accessibility Access") {
                    appModel.requestAccessibilityAccess()
                }
            }

            SettingsLink {
                Text("Settings")
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}
