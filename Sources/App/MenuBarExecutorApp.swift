import SwiftUI

@main
struct MenuBarExecutorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            CommandsListView()
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}
