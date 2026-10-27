import SwiftUI

struct CommandEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = CommandsManager.shared
    let command: Command?
    @State private var name: String
    @State private var commandText: String
    @State private var workingDirectory: String
    @State private var notification: Bool
    @State private var autoExecute: Bool
    @State private var group: String
    @State private var directExecution: Bool
    @State private var showingDeleteConfirmation = false
    @FocusState private var nameFocused: Bool

    let onSave: (Command) -> Void
    var onDelete: (() -> Void)?

    init(command: Command?, onSave: @escaping (Command) -> Void, onDelete: (() -> Void)? = nil) {
        self.command = command
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: command?.name ?? "")
        _commandText = State(initialValue: command?.command ?? "")
        _workingDirectory = State(initialValue: command?.workingDirectory ?? "")
        _notification = State(initialValue: command?.notification ?? true)
        _autoExecute = State(initialValue: command?.autoExecute ?? false)
        _group = State(initialValue: command?.group ?? "")
        _directExecution = State(initialValue: command?.directExecution ?? false)
    }

    var isExisting: Bool { onDelete != nil }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isExisting ? "编辑命令" : "添加命令").font(.headline)
                Text("名称用于搜索，命令内容交给 zsh 执行。").font(.caption).foregroundColor(InterfaceStyle.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(InterfaceStyle.material)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("命令名称") {
                        TextField("例如：启动 Docker 服务", text: $name).focused($nameFocused)
                    }
                    field("命令内容") {
                        TextEditor(text: $commandText)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 96)
                            .padding(5)
                            .background(InterfaceStyle.surface)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15)))
                    }
                    HStack(alignment: .top, spacing: 16) {
                        field("分组 · 可选") {
                            CommandGroupField(text: $group, groups: CommandsManager.sortedGroupNames(from: manager.commands, groupOrder: nil).compactMap { $0 })
                        }
                        field("工作目录 · 可选") {
                            HStack {
                                TextField("默认工作目录", text: $workingDirectory)
                                Button("选择…", action: chooseDirectory)
                            }
                            Text("支持 ~，留空使用默认目录。").font(.caption).foregroundColor(InterfaceStyle.muted)
                        }
                    }
                    Divider()
                    Text("执行行为").font(.caption).fontWeight(.semibold)
                    option("打开面板时自动执行", detail: "每次打开都会运行，结果显示在行内，不计入历史、不发送通知。", isOn: $autoExecute)
                    option("直接执行", detail: "跳过 ~/.zshrc，启动更快；其中的 alias、函数和环境变量不可用。", isOn: $directExecution)
                    Toggle("手动执行完成后通知", isOn: $notification)
                    Text("命令超过 30 秒会终止。").font(.caption).foregroundColor(InterfaceStyle.muted)
                }.padding(24).textFieldStyle(.roundedBorder)
            }
            Divider()
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                if isExisting {
                    Button("删除命令…", role: .destructive) { showingDeleteConfirmation = true }
                }
                Spacer()
                Button("保存命令", action: saveCommand)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(16).background(InterfaceStyle.chrome)
        }
        .font(.system(size: 13)).foregroundColor(InterfaceStyle.text).background(InterfaceStyle.surface)
        .frame(width: 570, height: min(590, (NSScreen.main?.visibleFrame.height ?? 638) - 48))
        .onAppear { nameFocused = true }
        .alert("删除命令？", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除命令", role: .destructive) { onDelete?(); dismiss() }
        } message: {
            Text("将删除「\(command?.name ?? "")」。此操作无法撤销。")
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).fontWeight(.medium)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func option(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(title, isOn: isOn)
            Text(detail).font(.caption).foregroundColor(InterfaceStyle.muted).padding(.leading, 20)
        }
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择工作目录"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if !workingDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: (workingDirectory as NSString).expandingTildeInPath)
        }
        if panel.runModal() == .OK, let url = panel.url { workingDirectory = url.path }
    }

    private func saveCommand() {
        onSave(Command(
            id: command?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            command: commandText.trimmingCharacters(in: .whitespacesAndNewlines),
            workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
            notification: notification, autoExecute: autoExecute,
            group: group.isEmpty ? nil : group, directExecution: directExecution
        ))
        dismiss()
    }
}

private struct CommandGroupField: NSViewRepresentable {
    @Binding var text: String
    let groups: [String]

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    func makeNSView(context: Context) -> NSComboBox {
        let box = NSComboBox()
        box.isEditable = true
        box.completes = true
        box.placeholderString = "选择或输入分组"
        box.font = .systemFont(ofSize: 13)
        box.delegate = context.coordinator
        box.setAccessibilityLabel("分组")
        return box
    }
    func updateNSView(_ box: NSComboBox, context: Context) {
        context.coordinator.text = $text
        if box.objectValues.compactMap({ $0 as? String }) != groups {
            box.removeAllItems()
            box.addItems(withObjectValues: groups)
        }
        if box.stringValue != text { box.stringValue = text }
    }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func controlTextDidChange(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox else { return }
            text.wrappedValue = box.stringValue
        }
        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let box = notification.object as? NSComboBox,
                  let value = box.objectValueOfSelectedItem as? String else { return }
            text.wrappedValue = value
        }
    }
}
