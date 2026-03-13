import SwiftUI

@main
struct PasteDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel.shared

    var body: some Scene {
        MenuBarExtra("PasteDock", systemImage: "list.clipboard") {
            MenuBarContentView()
                .environmentObject(appModel)
        }

        Settings {
            SettingsView()
                .environmentObject(appModel)
                .frame(minWidth: 520, minHeight: 420)
        }
    }
}
