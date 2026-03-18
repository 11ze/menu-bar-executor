import SwiftUI

struct CommandsListView: View {
    @ObservedObject private var manager = CommandsManager.shared
    @State private var editingCommand: Command?
    @State private var showingEditor = false
    @State private var commandToDelete: Command?
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""

    // 按搜索文本过滤命令
    private var filteredCommands: [Command] {
        if searchText.isEmpty {
            return manager.commands
        }
        return manager.commands.filter { command in
            command.name.localizedCaseInsensitiveContains(searchText) ||
            command.command.localizedCaseInsensitiveContains(searchText) ||
            (command.group?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

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

            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索命令...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 命令列表
            List {
                ForEach(filteredCommands) { command in
                    HStack {
                        Image(systemName: command.icon ?? "terminal.fill")
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(command.name)
                                    .font(.body)
                                if let group = command.group {
                                    Text(group)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                if let shortcut = command.shortcut {
                                    Text("⌘\(shortcut.uppercased())")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                            Text(command.command)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
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
                                commandToDelete = command
                                showingDeleteConfirmation = true
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
        .frame(minWidth: 650, minHeight: 450)
        .sheet(isPresented: $showingEditor) {
            CommandEditorView(command: editingCommand) { command in
                if editingCommand != nil {
                    manager.updateCommand(command)
                } else {
                    manager.addCommand(command)
                }
            }
        }
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("删除", role: .destructive) {
                if let command = commandToDelete {
                    manager.deleteCommand(id: command.id)
                }
                commandToDelete = nil
            }
            Button("取消", role: .cancel) {
                commandToDelete = nil
            }
        } message: {
            Text("确定要删除命令「\(commandToDelete?.name ?? "")」吗？")
        }
        .alert("操作失败", isPresented: Binding(
            get: { manager.lastError != nil },
            set: { if !$0 { manager.clearError() } }
        )) {
            Button("确定", role: .cancel) {
                manager.clearError()
            }
        } message: {
            Text(manager.lastError?.errorDescription ?? "未知错误")
        }
    }
}

#Preview {
    CommandsListView()
}
