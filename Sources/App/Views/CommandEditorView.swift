import SwiftUI

struct CommandEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let command: Command?
    @State private var name: String
    @State private var commandText: String
    @State private var workingDirectory: String
    @State private var notification: Bool
    @State private var autoExecute: Bool
    @State private var group: String

    let onSave: (Command) -> Void

    init(command: Command?, onSave: @escaping (Command) -> Void) {
        self.command = command
        self.onSave = onSave

        if let command = command {
            _name = State(initialValue: command.name)
            _commandText = State(initialValue: command.command)
            _workingDirectory = State(initialValue: command.workingDirectory ?? "")
            _notification = State(initialValue: command.notification)
            _autoExecute = State(initialValue: command.autoExecute)
            _group = State(initialValue: command.group ?? "")
        } else {
            _name = State(initialValue: "")
            _commandText = State(initialValue: "")
            _workingDirectory = State(initialValue: "")
            _notification = State(initialValue: true)
            _autoExecute = State(initialValue: false)
            _group = State(initialValue: "")
        }
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("命令名称", text: $name)
                TextField("命令内容", text: $commandText)
                TextField("分组（可选）", text: $group)
                TextField("工作目录（可选）", text: $workingDirectory)
            }

            Section("显示设置") {
                Toggle("显示通知", isOn: $notification)
                Toggle("打开面板时自动执行", isOn: $autoExecute)
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
        .frame(minWidth: 400, minHeight: 250)
        .padding()
    }

    private func saveCommand() {
        let newCommand = Command(
            id: command?.id ?? UUID(),
            name: name,
            command: commandText,
            workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
            notification: notification,
            autoExecute: autoExecute,
            group: group.isEmpty ? nil : group
        )
        onSave(newCommand)
        dismiss()
    }
}

#Preview {
    CommandEditorView(command: nil) { _ in }
}
