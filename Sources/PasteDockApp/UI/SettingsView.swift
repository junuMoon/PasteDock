import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PasteDock Settings")
                .font(.title2.weight(.semibold))

            Text("Launched at \(appModel.launchDate.formatted(date: .abbreviated, time: .standard))")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
    }
}
