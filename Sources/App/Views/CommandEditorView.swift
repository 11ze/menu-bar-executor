import SwiftUI

struct CommandEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = CommandsManager.shared
    @ObservedObject private var settings = AppSettingsManager.shared
    let command: Command?
    @State private var name: String
    @State private var commandText: String
    @State private var workingDirectory: String
    @State private var notification: Bool
    @State private var autoExecute: Bool
    @State private var group: String
    @State private var directExecution: Bool
    @State private var hidden: Bool
    @State private var showingDeleteConfirmation = false
    @State private var formHeight: CGFloat = 532

    let onSave: (Command) -> Bool
    var onDelete: (() -> Bool)?

    init(command: Command?, onSave: @escaping (Command) -> Bool, onDelete: (() -> Bool)? = nil) {
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
        _hidden = State(initialValue: command?.hidden ?? false)
    }

    var isExisting: Bool { onDelete != nil }

    private var selectedGroupIsHidden: Bool {
        manager.groupVisibility.isGroupHidden(group)
    }

    private var autoExecutePauseMessage: String? {
        guard autoExecute, hidden || selectedGroupIsHidden else { return nil }
        let normalized = CommandsManager.normalizedGroup(group)
        let groupDesc = normalized.map { "分组「\($0)」" } ?? "未分组"
        if hidden && selectedGroupIsHidden {
            return "当前命令及所属\(groupDesc)均已隐藏，恢复显示后才会自动执行。"
        }
        if hidden {
            return "当前命令已设为隐藏，恢复显示后才会自动执行。"
        }
        return "所属\(groupDesc)当前已隐藏，恢复显示后才会自动执行。"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isExisting ? "编辑命令" : "添加命令").font(.system(size: 16, weight: .semibold))
                Text("名称用于搜索，命令内容交给 zsh 执行。").font(.system(size: 12)).foregroundColor(InterfaceStyle.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.vertical, 16)
                .frame(height: 79).background(InterfaceStyle.material)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    field("命令名称") {
                        InterfaceTextField(placeholder: "例如：启动 Docker 服务", text: $name, autoFocus: true)
                    }
                    field("命令内容") {
                        commandInput
                    }
                    HStack(alignment: .top, spacing: 16) {
                        field("分组", optional: true) {
                            CommandGroupField(text: $group, groups: CommandsManager.managedGroupNames(from: manager.commands, groupOrder: settings.settings.groupOrder))
                        }
                        .frame(width: (620 - 24 * 2 - 16) / 2.4)
                        field("工作目录", optional: true) {
                            HStack {
                                InterfaceTextField(placeholder: "默认工作目录", text: $workingDirectory)
                                Button("选择…", action: chooseDirectory)
                            }
                            Text("支持 ~，留空使用默认目录。").font(.system(size: 12)).foregroundColor(InterfaceStyle.muted)
                                .frame(minHeight: 18, alignment: .leading)
                        }
                    }
                    Divider()
                    option("打开面板时自动执行", detail: "每次打开都会运行；结果显示在行内，不计入历史、不通知。", isOn: $autoExecute)
                    option("直接执行", detail: "跳过 ~/.zshrc；其中的 alias、函数和环境变量不可用。", isOn: $directExecution)
                    Toggle("手动执行完成后通知", isOn: $notification)
                        .toggleStyle(InterfaceCheckboxToggleStyle())
                        .font(.system(size: 12))
                    option("在命令面板中隐藏", detail: "隐藏后不出现在命令面板和搜索中，自动执行也会暂停。", isOn: $hidden)
                    if let pauseMessage = autoExecutePauseMessage {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 11))
                                .foregroundColor(InterfaceStyle.muted)
                                .padding(.top, 2)
                            Text("自动执行暂不生效：\(pauseMessage)")
                                .font(.system(size: 12))
                                .foregroundColor(InterfaceStyle.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(InterfaceStyle.subtle)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(InterfaceStyle.line, lineWidth: 1))
                        .cornerRadius(7)
                    } else {
                        Text("命令超过 30 秒会终止。").font(.system(size: 12)).foregroundColor(InterfaceStyle.muted)
                            .frame(minHeight: 18, alignment: .leading)
                    }
                }.padding(.horizontal, 24).padding(.vertical, 16)
                    .background(GeometryReader { geometry in
                        Color.clear.onAppear { formHeight = geometry.size.height }
                            .onChange(of: geometry.size.height) { formHeight = $0 }
                    })
            }
            .frame(height: min(formHeight, max(0, min(740, (NSScreen.main?.visibleFrame.height ?? 780) - 40) - 140)))
            Divider()
            HStack(spacing: 8) {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                if isExisting {
                    Button(role: .destructive) { showingDeleteConfirmation = true } label: { Text("删除命令…").foregroundColor(InterfaceStyle.failure) }.buttonStyle(CompactQuietButtonStyle())
                }
                Spacer()
                Button("保存命令") { saveCommand() }
                    .buttonStyle(InterfaceButtonStyle(prominent: true, height: 30)).keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.font(.system(size: 12)).padding(.horizontal, 20).padding(.vertical, 14).frame(height: 59).background(InterfaceStyle.chrome)
        }
        .font(.system(size: 13)).foregroundColor(InterfaceStyle.text).background(InterfaceStyle.surface)
        .buttonStyle(InterfaceButtonStyle(height: 30))
        .frame(width: 620)
        .alert("操作失败", isPresented: Binding(
            get: { settings.lastError != nil },
            set: { if !$0 { settings.lastError = nil } }
        )) {
            Button("确定", role: .cancel) { settings.lastError = nil }
        } message: {
            Text(settings.lastError?.errorDescription ?? "未知错误")
        }
        .alert("删除命令？", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除命令", role: .destructive) { if onDelete?() == true { dismiss() } }
        } message: {
            Text("将删除「\(command?.name ?? "")」。此操作无法撤销。")
        }
    }

    private var commandInput: some View {
        Group {
            if #available(macOS 13.0, *) {
                TextEditor(text: $commandText).scrollContentBackground(.hidden)
            } else {
                TextEditor(text: $commandText)
            }
        }.font(.system(size: 13, design: .monospaced)).frame(height: 62).padding(5)
            .background(InterfaceStyle.surface)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(InterfaceStyle.line, lineWidth: 1))
    }

    private func field<Content: View>(_ title: String, optional: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Text(title).font(.system(size: 12, weight: .medium))
                if optional { Text("（可选）").font(.system(size: 12)).foregroundColor(InterfaceStyle.muted) }
            }.frame(minHeight: 18, alignment: .leading)
            content()
        }.font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func option(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(title, isOn: isOn)
                .toggleStyle(InterfaceCheckboxToggleStyle())
                .font(.system(size: 12))
            Text(detail).font(.system(size: 12)).foregroundColor(InterfaceStyle.muted).padding(.leading, 23)
                .frame(minHeight: 18, alignment: .leading)
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

    @discardableResult
    func saveCommand() -> Bool {
        let trimmedGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = onSave(Command(
            id: command?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            command: commandText,
            workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
            notification: notification, autoExecute: autoExecute,
            group: trimmedGroup.isEmpty ? nil : trimmedGroup, directExecution: directExecution,
            hidden: hidden
        ))
        if saved { dismiss() }
        return saved
    }
}

/// 与单行输入框同高（36pt）的分组组合框：输入复用中文组词保护，右侧展开原生系统下拉菜单。
struct CommandGroupField: View {
    @Binding var text: String
    let groups: [String]
    @State private var focused = false
    @State private var boxWidth: CGFloat = 224

    static func menuPopupGeometry(boxWidth: CGFloat, buttonSize: NSSize) -> (minimumWidth: CGFloat, origin: NSPoint) {
        let width = max(140, boxWidth)
        return (width, NSPoint(x: -(width - buttonSize.width), y: buttonSize.height + 4))
    }

    var body: some View {
        HStack(spacing: 0) {
            NativeFormTextField(
                placeholder: "选择或输入分组",
                accessibilityLabel: "分组",
                text: $text,
                trailingInset: groups.isEmpty ? 10 : 4,
                focused: $focused
            )
            if !groups.isEmpty {
                GroupDropdownButton(groups: groups, menuWidth: boxWidth, selection: $text)
                    .frame(width: 28, height: 34)
            }
        }
        .modifier(InterfaceFieldChrome(focused: focused))
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { boxWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { boxWidth = $0 }
        })
    }
}

private struct GroupDropdownButton: NSViewRepresentable {
    let groups: [String]
    let menuWidth: CGFloat
    @Binding var selection: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.bezelStyle = .inline
        button.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "展开分组列表")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
        button.contentTintColor = NSColor(InterfaceStyle.muted)
        button.setAccessibilityLabel("展开分组列表")
        button.toolTip = "选择已有分组"
        button.target = context.coordinator
        button.action = #selector(Coordinator.showMenu(_:))
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
        button.contentTintColor = NSColor(InterfaceStyle.muted)
    }

    final class Coordinator: NSObject {
        var parent: GroupDropdownButton
        init(_ parent: GroupDropdownButton) { self.parent = parent }

        @objc func showMenu(_ sender: NSButton) {
            let menu = NSMenu()
            let current = parent.selection.trimmingCharacters(in: .whitespacesAndNewlines)
            for group in parent.groups {
                let item = NSMenuItem(title: group, action: #selector(selectGroup(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = group
                item.state = (group == current) ? .on : .off
                menu.addItem(item)
            }
            let geometry = CommandGroupField.menuPopupGeometry(boxWidth: parent.menuWidth, buttonSize: sender.bounds.size)
            menu.minimumWidth = geometry.minimumWidth
            menu.popUp(positioning: nil, at: geometry.origin, in: sender)
        }

        @objc private func selectGroup(_ sender: NSMenuItem) {
            guard let group = sender.representedObject as? String else { return }
            parent.selection = group
        }
    }
}
