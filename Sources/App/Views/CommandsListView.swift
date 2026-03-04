import SwiftUI

struct CommandsListView: View {
    @StateObject private var manager = CommandsManager.shared
    @State private var editingCommand: Command?
    @State private var showingEditor = false

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("命令管理")
                    .font(.headline)
                Spacer()
                Button(action: {
                    editingCommand = nil
                    showingEditor = true
                }) {
                    Label("添加命令", systemImage: "plus")
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 命令列表
            List {
                ForEach(manager.commands) { command in
                    HStack {
                        Image(systemName: command.icon ?? "terminal.fill")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(command.name)
                                .font(.body)
                            Text(command.command)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Button(action: {
                                editingCommand = command
                                showingEditor = true
                            }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)

                            Button(action: {
                                deleteCommand(command)
                            }) {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showingEditor) {
            CommandEditorView(command: editingCommand) { command in
                if editingCommand != nil {
                    manager.updateCommand(command)
                } else {
                    manager.addCommand(command)
                }
            }
        }
    }

    private func deleteCommand(_ command: Command) {
        let alert = NSAlert()
        alert.messageText = "确认删除"
        alert.informativeText = "确定要删除命令「\(command.name)」吗？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            manager.deleteCommand(id: command.id)
        }
    }
}

#Preview {
    CommandsListView()
}
