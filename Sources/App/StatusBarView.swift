import SwiftUI

struct StatusBarView: View {
    @StateObject private var manager = CommandsManager.shared

    var body: some View {
        Menu {
            ForEach(manager.commands) { command in
                Button(action: {
                    manager.execute(command)
                }) {
                    Label(
                        command.name,
                        systemImage: command.icon ?? "terminal.fill"
                    )
                }
            }

            Divider()

            Button(action: {
                manager.reload()
            }) {
                Label("重载配置", systemImage: "arrow.clockwise")
            }

            Divider()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("退出", systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "terminal.fill")
                .font(.system(size: 14))
        }
        .menuStyle(.borderlessButton)
    }
}
