import SwiftUI

struct CommandsListView: View {
    @ObservedObject private var manager = CommandsManager.shared
    @ObservedObject private var settings = AppSettingsManager.shared
    @State private var editingCommand: Command?
    @State private var searchText = ""
    @State private var hoveredCommandID: UUID?
    @FocusState private var searchFocused: Bool

    private var listModel: PaletteListModel {
        PaletteListModel.derive(commands: manager.commands, searchText: searchText,
                                groupOrder: settings.settings.groupOrder,
                                previousIndex: 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(InterfaceStyle.muted)
                    TextField("搜索命令标题", text: $searchText).textFieldStyle(.plain).focused($searchFocused)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").frame(width: 24, height: 24).contentShape(Rectangle())
                        }
                            .buttonStyle(.plain).accessibilityLabel("清空搜索")
                    }
                }
                .modifier(ToolbarSearchStyle(focused: searchFocused))
                Button { editingCommand = Command(name: "", command: "") } label: {
                    Label("添加命令", systemImage: "plus")
                }.buttonStyle(.borderedProminent).controlSize(.large)
            }
            .padding(.horizontal, 20).padding(.bottom, 16)
            .background(InterfaceStyle.material)
            Divider()
            HStack {
                Text("\(listModel.items.filter(\.isCommand).count) 条命令")
                Spacer()
                Text("按分组显示，与命令面板一致")
            }.font(.caption).foregroundColor(InterfaceStyle.muted).padding(.horizontal, 20).padding(.vertical, 10)

            if listModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: searchText.isEmpty ? "terminal" : "magnifyingglass").font(.largeTitle)
                    Text(searchText.isEmpty ? "暂无命令" : "未找到匹配命令")
                    Button(searchText.isEmpty ? "添加命令" : "清空搜索") {
                        if searchText.isEmpty { editingCommand = Command(name: "", command: "") }
                        else { searchText = "" }
                    }
                }.foregroundColor(InterfaceStyle.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(listModel.items) { item in
                            switch item {
                            case .groupHeader(let name):
                                Text(name).font(.caption).fontWeight(.semibold).foregroundColor(InterfaceStyle.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 7)
                            case .command(let command, _):
                                commandRow(command)
                            }
                        }
                    }
                }
            }
            Divider()
            HStack {
                Text("选择命令后编辑，箭头可调整组内顺序")
                Spacer()
                Text("\(manager.commands.filter(\.autoExecute).count) 条自动执行")
            }.font(.caption).foregroundColor(InterfaceStyle.muted).padding(.horizontal, 20).padding(.vertical, 10)
                .background(InterfaceStyle.chrome)
        }
        .sheet(item: $editingCommand) { command in
            CommandEditorView(command: command, onSave: { manager.upsert($0) }, onDelete: manager.commands.contains(where: { $0.id == command.id }) ? {
                manager.deleteCommand(id: command.id)
            } : nil)
        }
    }

    private func commandRow(_ command: Command) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(command.name).lineLimit(1)
                    if command.autoExecute {
                        Text("自动执行").font(.system(size: 10)).foregroundColor(InterfaceStyle.muted)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(InterfaceStyle.chrome).cornerRadius(4)
                    }
                }
                Text(command.command).font(.system(size: 11, design: .monospaced)).foregroundColor(InterfaceStyle.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            HStack(spacing: 3) {
                Button { editingCommand = command } label: {
                    Text("编辑")
                }
                Button { manager.moveUp(command) } label: { Image(systemName: "arrow.up") }
                    .disabled(!searchText.isEmpty || !manager.canMoveUp(command))
                    .accessibilityLabel("在组内上移\(command.name)")
            }.buttonStyle(CommandRowButtonStyle())
        }
        .padding(.horizontal, 20).frame(height: 67)
        .background(hoveredCommandID == command.id ? InterfaceStyle.subtle : .clear)
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
        .onHover { hovered in
            if hovered { hoveredCommandID = command.id }
            else if hoveredCommandID == command.id { hoveredCommandID = nil }
        }
    }
}
