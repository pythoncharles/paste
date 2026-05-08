import SwiftUI

@main
struct PasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                store: appDelegate.store,
                themeManager: appDelegate.themeManager,
                settingsManager: appDelegate.settingsManager
            )
            .frame(width: 520, height: 520)
        }
    }
}
