import SwiftUI

@main
struct MenuBarExecutorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView().background(SettingsWindowChrome())
        }
    }
}
