import SwiftUI
import UniformTypeIdentifiers
import KeyboardShortcuts

struct CommandsListView: View {
    @ObservedObject private var manager = CommandsManager.shared
    @State private var editingCommand: Command?
    @State private var showingEditor = false
    @State private var commandToDelete: Command?
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""
    @State private var showingImportConfirmation = false
    @State private var importURL: URL?

    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()

    private var filteredCommands: [Command] {
        manager.filteredCommands(by: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("命令设置")
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    Button(action: exportConfig) {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    Button(action: showImportPanel) {
                        Label("导入", systemImage: "square.and.arrow.down")
                    }
                    Button(action: {
                        editingCommand = nil
                        showingEditor = true
                    }) {
                        Label("添加命令", systemImage: "plus")
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

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

            List {
                ForEach(searchText.isEmpty ? manager.commands : filteredCommands) { command in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(searchText.isEmpty ? .secondary : Color.gray.opacity(0.5))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(command.name)
                                .font(.body)
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
                .onMove(perform: searchText.isEmpty ? { source, destination in
                    manager.reorderCommands(from: source, to: destination)
                } : nil)
            }

            if manager.commands.count > 1 && searchText.isEmpty {
                Text("拖拽可排序")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
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
        .alert("确认导入", isPresented: $showingImportConfirmation) {
            Button("导入", role: .destructive) {
                if let url = importURL {
                    manager.importCommands(from: url)
                }
                importURL = nil
            }
            Button("取消", role: .cancel) {
                importURL = nil
            }
        } message: {
            Text("导入将覆盖当前所有命令配置，确定要继续吗？")
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                VStack(spacing: 12) {
                    // 全局快捷键
                    HStack {
                        Text("全局快捷键")
                            .font(.headline)
                        Spacer()
                        KeyboardShortcuts.Recorder("全局快捷键:", name: .commandPalette)
                        Button("清除") {
                            KeyboardShortcuts.setShortcut(nil, for: .commandPalette)
                        }
                    }

                    Divider()

                    // 默认输入法
                    HStack {
                        Text("默认输入法")
                            .font(.headline)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { AppSettingsManager.shared.settings.defaultInputSourceID ?? "" },
                            set: { newValue in
                                AppSettingsManager.shared.settings.defaultInputSourceID = newValue.isEmpty ? nil : newValue
                                AppSettingsManager.shared.save()
                            }
                        )) {
                            Text("不切换").tag("")
                            ForEach(InputSourceHelper.availableInputSources(), id: \.id) { source in
                                Text(source.name).tag(source.id)
                            }
                        }
                        .frame(width: 200)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
    }

    private func exportConfig() {
        let timestamp = Self.exportDateFormatter.string(from: Date())

        let panel = NSSavePanel()
        panel.title = "导出配置"
        panel.nameFieldStringValue = "commands-\(timestamp).json"
        panel.allowedContentTypes = [UTType.json]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            manager.exportConfig(to: url)
        }
    }

    private func showImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "导入配置"
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            importURL = url
            showingImportConfirmation = true
        }
    }
}

#Preview {
    CommandsListView()
}
