import SwiftUI

struct CommandEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = CommandsManager.shared

    let command: Command?
    @State private var name: String
    @State private var commandText: String
    @State private var workingDirectory: String
    @State private var iconName: String
    @State private var notification: Bool
    @State private var group: String
    @State private var shortcut: String
    @State private var newGroup: String = ""
    @State private var showNewGroupField = false

    let onSave: (Command) -> Void

    // 获取所有现有分组
    private var existingGroups: [String] {
        let groups = Set(manager.commands.compactMap { $0.group })
        return Array(groups).sorted()
    }

    // 检查快捷键冲突
    private var shortcutConflict: Bool {
        guard !shortcut.isEmpty else { return false }
        return manager.commands.contains { cmd in
            cmd.id != command?.id && cmd.shortcut?.lowercased() == shortcut.lowercased()
        }
    }

    // 获取已使用的快捷键列表
    private var usedShortcuts: [(shortcut: String, commandName: String)] {
        manager.commands.compactMap { cmd in
            guard let s = cmd.shortcut, !s.isEmpty, cmd.id != command?.id else { return nil }
            return (s, cmd.name)
        }.sorted { $0.shortcut < $1.shortcut }
    }

    init(command: Command?, onSave: @escaping (Command) -> Void) {
        self.command = command
        self.onSave = onSave

        if let command = command {
            _name = State(initialValue: command.name)
            _commandText = State(initialValue: command.command)
            _workingDirectory = State(initialValue: command.workingDirectory ?? "")
            _iconName = State(initialValue: command.icon ?? "terminal.fill")
            _notification = State(initialValue: command.notification)
            _group = State(initialValue: command.group ?? "")
            _shortcut = State(initialValue: command.shortcut ?? "")
        } else {
            _name = State(initialValue: "")
            _commandText = State(initialValue: "")
            _workingDirectory = State(initialValue: "")
            _iconName = State(initialValue: "terminal.fill")
            _notification = State(initialValue: true)
            _group = State(initialValue: "")
            _shortcut = State(initialValue: "")
        }
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("命令名称", text: $name)
                TextField("命令内容", text: $commandText)
                TextField("工作目录（可选）", text: $workingDirectory)
            }

            Section("分组设置") {
                HStack {
                    Picker("分组", selection: $group) {
                        Text("无分组").tag("")
                        ForEach(existingGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .frame(width: 200)

                    Button(action: {
                        showNewGroupField.toggle()
                    }) {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                }

                if showNewGroupField {
                    HStack {
                        TextField("新分组名称", text: $newGroup)
                        Button("添加") {
                            if !newGroup.isEmpty && !existingGroups.contains(newGroup) {
                                group = newGroup
                                newGroup = ""
                                showNewGroupField = false
                            }
                        }
                        .disabled(newGroup.isEmpty)
                    }
                }
            }

            Section("显示设置") {
                HStack {
                    TextField("图标名称（SF Symbol）", text: $iconName)
                    Image(systemName: iconName.isEmpty ? "terminal.fill" : iconName)
                        .foregroundColor(.secondary)
                }
                Toggle("显示通知", isOn: $notification)
            }

            Section("快捷键") {
                HStack {
                    TextField("快捷键（如：r, 1, F1）", text: $shortcut)
                        .help("输入单个字符或功能键名称")

                    if shortcutConflict {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .help("快捷键已被其他命令使用")
                    }
                }

                if shortcutConflict {
                    Text("⚠️ 快捷键冲突：此快捷键已被使用")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                if !usedShortcuts.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已使用的快捷键：")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(usedShortcuts, id: \.commandName) { item in
                            Text("  ⌘\(item.shortcut.uppercased()) - \(item.commandName)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Button("取消") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("保存") {
                        saveCommand()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || commandText.isEmpty)
                }
            }
        }
        .frame(minWidth: 450, minHeight: 400)
        .padding()
    }

    private func saveCommand() {
        let newCommand = Command(
            id: command?.id ?? UUID(),
            name: name,
            command: commandText,
            workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
            icon: iconName.isEmpty ? nil : iconName,
            notification: notification,
            group: group.isEmpty ? nil : group,
            shortcut: shortcut.isEmpty ? nil : shortcut.lowercased()
        )
        onSave(newCommand)
        dismiss()
    }
}

#Preview {
    CommandEditorView(command: nil) { _ in }
}
