import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PasteDock")
                .font(.headline)

            Text("App shell is ready.")
                .foregroundStyle(.secondary)

            Divider()

            SettingsLink {
                Text("Settings")
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 240)
    }
}
