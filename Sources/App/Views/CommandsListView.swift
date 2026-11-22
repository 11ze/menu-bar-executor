import SwiftUI
import UniformTypeIdentifiers

struct CommandsListView: View {
    private static let dragItemUTType = UTType(exportedAs: "com.cai.menu-bar-executor.drag-item", conformingTo: .data)

    private enum SelectedGroup: Hashable {
        case named(String)
        case ungrouped
    }

    private enum DragItem: Equatable {
        case group(String)
        case command(UUID)
    }

    private struct SearchSection: Identifiable {
        let group: String?
        let commands: [Command]
        var id: String { group.map { "named-\($0)" } ?? "ungrouped" }
        var title: String { group ?? "未分组" }
    }

    @ObservedObject private var manager = CommandsManager.shared
    @ObservedObject private var settings = AppSettingsManager.shared
    @State private var selectedGroup: SelectedGroup?
    @State private var editingCommand: Command?
    @State private var searchText = ""
    @State private var hoveredCommandID: UUID?
    @State private var hoveredGroupKey: SelectedGroup?
    @State private var renamingGroup: String?
    @State private var renameDraft = ""
    @State private var isCreatingGroup = false
    @State private var newGroupDraft = ""
    @State private var pendingDeleteGroup: String?
    @State private var showingDeleteGroupConfirmation = false
    @State private var draggingItem: DragItem?
    @State private var dropReorderGroup: String?
    @State private var dropReceiveGroup: SelectedGroup?
    @State private var dropReorderCommandID: UUID?
    @FocusState private var searchFocused: Bool
    @FocusState private var renameFieldFocused: Bool
    @FocusState private var newGroupFieldFocused: Bool

    private var managedGroups: [String] {
        CommandsManager.managedGroupNames(from: manager.commands, groupOrder: settings.settings.groupOrder)
    }

    private var effectiveSelection: SelectedGroup {
        if let selectedGroup {
            switch selectedGroup {
            case .named(let name) where managedGroups.contains(name):
                return .named(name)
            case .ungrouped:
                return .ungrouped
            case .named:
                break
            }
        }
        if let firstNonEmpty = managedGroups.first(where: { name in
            manager.commands.contains { CommandsManager.normalizedGroup($0.group) == name }
        }) {
            return .named(firstNonEmpty)
        }
        if ungroupedCount > 0 {
            return .ungrouped
        }
        return managedGroups.first.map(SelectedGroup.named) ?? .ungrouped
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchSections: [SearchSection] {
        let filtered = CommandsManager.filteredCommands(from: manager.commands, by: searchText)
        let grouped = Dictionary(grouping: filtered, by: { CommandsManager.normalizedGroup($0.group) })
        let ordered = CommandsManager.sortedGroupNames(from: filtered, groupOrder: settings.settings.groupOrder)
        return ordered.compactMap { group in
            guard let items = grouped[group], !items.isEmpty else { return nil }
            return SearchSection(group: group, commands: items)
        }
    }

    private var searchMatchCount: Int {
        searchSections.reduce(0) { $0 + $1.commands.count }
    }

    private var currentGroupCommands: [Command] {
        switch effectiveSelection {
        case .named(let name):
            return manager.commands.filter { CommandsManager.normalizedGroup($0.group) == name }
        case .ungrouped:
            return manager.commands.filter { CommandsManager.normalizedGroup($0.group) == nil }
        }
    }

    private var ungroupedCount: Int {
        manager.commands.filter { CommandsManager.normalizedGroup($0.group) == nil }.count
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    sidebarView
                        .frame(width: geometry.size.width < 720 ? 184 : 224)
                    Divider()
                    mainPanelView
                }
                Divider()
                HStack {
                    Text("拖动命令可组内排序，拖到左侧分组可跨组移动")
                    Spacer()
                    Text("共 \(manager.commands.count) 条 · \(manager.commands.filter(\.autoExecute).count) 条自动执行")
                }
                .font(.system(size: 12))
                .foregroundColor(InterfaceStyle.muted)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(InterfaceStyle.chrome)
            }
        }
        .onChange(of: searchText) { _ in clearDragState() }
        .onChange(of: renameFieldFocused) { focused in
            if !focused, let name = renamingGroup {
                commitRename(oldName: name)
            }
        }
        .onChange(of: newGroupFieldFocused) { focused in
            if !focused, isCreatingGroup {
                commitNewGroup()
            }
        }
        .alert("操作失败", isPresented: Binding(
            get: { editingCommand == nil && !showingDeleteGroupConfirmation && settings.lastError != nil },
            set: { if !$0 { settings.lastError = nil } }
        )) {
            Button("确定", role: .cancel) { settings.lastError = nil }
        } message: {
            Text(settings.lastError?.errorDescription ?? "未知错误")
        }
        .sheet(item: $editingCommand) { command in
            CommandEditorView(
                command: command,
                onSave: { manager.upsert($0) },
                onDelete: manager.commands.contains(where: { $0.id == command.id }) ? {
                    manager.deleteCommand(id: command.id)
                } : nil
            )
        }
    }

    // MARK: - 左侧纯分组栏

    private var sidebarView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    sidebarSectionHeader(title: "分组", hint: "拖动排序")
                        .padding(.top, 4)

                    ForEach(managedGroups, id: \.self) { name in
                        namedGroupRow(name)
                    }

                    if isCreatingGroup {
                        newGroupRow
                    }

                    sidebarSectionHeader(title: "默认", hint: "固定末尾")
                        .padding(.top, 8)

                    ungroupedRow
                }
                .padding(8)
            }
            Divider()
            Button {
                startCreatingGroup()
            } label: {
                Label("新建分组", systemImage: "plus")
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(InterfaceButtonStyle(height: 30))
            .padding(8)
        }
        .background(InterfaceStyle.material)
        .alert("删除分组？", isPresented: $showingDeleteGroupConfirmation, presenting: pendingDeleteGroup) { name in
            Button("取消", role: .cancel) { pendingDeleteGroup = nil }
            Button("删除分组", role: .destructive) {
                pendingDeleteGroup = nil
                DispatchQueue.main.async {
                    dissolveGroup(name)
                }
            }
        } message: { name in
            let count = manager.commands.filter { CommandsManager.normalizedGroup($0.group) == name }.count
            Text(count > 0
                ? "将删除分组「\(name)」，组内 \(count) 条命令会移入「未分组」，不会被删除。"
                : "将删除空分组「\(name)」。")
        }
    }

    private func sidebarSectionHeader(title: String, hint: String) -> some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .semibold))
            Spacer(minLength: 4)
            Text(hint).font(.system(size: 11)).opacity(0.75)
        }
        .foregroundColor(InterfaceStyle.muted)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func groupReorderAlignment(for targetGroup: String) -> Alignment {
        guard case .group(let source) = draggingItem,
              let from = managedGroups.firstIndex(of: source),
              let to = managedGroups.firstIndex(of: targetGroup) else {
            return .top
        }
        return from < to ? .bottom : .top
    }

    private func commandReorderAlignment(for targetID: UUID) -> Alignment {
        guard case .command(let sourceID) = draggingItem,
              let from = currentGroupCommands.firstIndex(where: { $0.id == sourceID }),
              let to = currentGroupCommands.firstIndex(where: { $0.id == targetID }) else {
            return .top
        }
        return from < to ? .bottom : .top
    }

    private func namedGroupRow(_ name: String) -> some View {
        let key = SelectedGroup.named(name)
        let isActive = !isSearching && effectiveSelection == key
        let isHovered = hoveredGroupKey == key
        let isReceiving = dropReceiveGroup == key
        let isReorderingTarget = dropReorderGroup == name
        let count = manager.commands.filter { CommandsManager.normalizedGroup($0.group) == name }.count

        return Group {
            if renamingGroup == name {
                HStack(spacing: 6) {
                    dragGrip(visible: true)
                    TextField("分组名称", text: $renameDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 6)
                        .frame(height: 24)
                        .background(InterfaceStyle.surface)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(InterfaceStyle.selectedText, lineWidth: 1))
                        .cornerRadius(5)
                        .focused($renameFieldFocused)
                        .onSubmit { commitRename(oldName: name) }
                        .onExitCommand { cancelRenamingGroup() }
                }
                .padding(.horizontal, 8)
                .frame(height: 34)
                .background(isActive ? InterfaceStyle.selection : Color.clear)
                .cornerRadius(7)
            } else {
                HStack(spacing: 6) {
                    Button {
                        selectGroup(key)
                    } label: {
                        HStack(spacing: 6) {
                            dragGrip(visible: isHovered || isActive)
                            Text(name)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(isActive || isReceiving ? InterfaceStyle.selectedRowText : InterfaceStyle.text)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                        }
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(name)

                    if isHovered {
                        HStack(spacing: 2) {
                            sidebarMiniButton(systemImage: "pencil", label: "重命名分组\(name)") {
                                startRenamingGroup(name)
                            }
                            sidebarMiniButton(systemImage: "xmark", label: "删除分组\(name)", destructive: true) {
                                requestDeleteGroup(name)
                            }
                        }
                    } else {
                        Text("\(count)")
                            .font(.system(size: 11))
                            .foregroundColor(isActive ? InterfaceStyle.selectedRowText : InterfaceStyle.muted)
                            .opacity(isActive ? 0.85 : 1)
                            .padding(.trailing, 4)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 34)
                .background(
                    isReceiving ? InterfaceStyle.selection :
                        (isActive ? InterfaceStyle.selection : (isHovered ? InterfaceStyle.subtle : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(
                            isReceiving ? InterfaceStyle.selectedText : Color.clear,
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                )
                .overlay(alignment: groupReorderAlignment(for: name)) {
                    if isReorderingTarget {
                        InterfaceStyle.selectedText.frame(height: 2)
                    }
                }
                .cornerRadius(7)
                .onHover { hovered in
                    if hovered { hoveredGroupKey = key }
                    else if hoveredGroupKey == key { hoveredGroupKey = nil }
                }
                .onDrag {
                    draggingItem = .group(name)
                    return Self.makeDragProvider("group:\(name)")
                }
                .onDrop(
                    of: [Self.dragItemUTType],
                    delegate: SidebarGroupDropDelegate(
                        dragUTType: Self.dragItemUTType,
                        targetGroup: name,
                        draggingItem: $draggingItem,
                        dropReorderGroup: $dropReorderGroup,
                        dropReceiveGroup: $dropReceiveGroup,
                        manager: manager,
                        onClearDrag: clearDragState
                    )
                )
            }
        }
    }

    private var newGroupRow: some View {
        HStack(spacing: 6) {
            dragGrip(visible: true)
            TextField("输入新分组名称", text: $newGroupDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 6)
                .frame(height: 24)
                .background(InterfaceStyle.surface)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(InterfaceStyle.selectedText, lineWidth: 1))
                .cornerRadius(5)
                .focused($newGroupFieldFocused)
                .onSubmit { commitNewGroup() }
                .onExitCommand { cancelCreatingGroup() }
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
    }

    private var ungroupedRow: some View {
        let key = SelectedGroup.ungrouped
        let isActive = !isSearching && effectiveSelection == key
        let isHovered = hoveredGroupKey == key
        let isReceiving = dropReceiveGroup == key

        return Button {
            selectGroup(key)
        } label: {
            HStack(spacing: 6) {
                Color.clear.frame(width: 14, height: 14)
                Text("未分组")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(isActive || isReceiving ? InterfaceStyle.selectedRowText : InterfaceStyle.muted)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(ungroupedCount)")
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? InterfaceStyle.selectedRowText : InterfaceStyle.muted)
                    .opacity(isActive ? 0.85 : 1)
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 8)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isReceiving ? InterfaceStyle.selection :
                (isActive ? InterfaceStyle.selection : (isHovered ? InterfaceStyle.subtle : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    isReceiving ? InterfaceStyle.selectedText : Color.clear,
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                )
        )
        .cornerRadius(7)
        .onHover { hovered in
            if hovered { hoveredGroupKey = key }
            else if hoveredGroupKey == key { hoveredGroupKey = nil }
        }
        .onDrop(
            of: [Self.dragItemUTType],
            delegate: UngroupedDropDelegate(
                dragUTType: Self.dragItemUTType,
                draggingItem: $draggingItem,
                dropReceiveGroup: $dropReceiveGroup,
                manager: manager,
                onClearDrag: clearDragState
            )
        )
    }

    private func sidebarMiniButton(
        systemImage: String,
        label: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(destructive ? InterfaceStyle.failure : InterfaceStyle.muted)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    // MARK: - 右侧命令区

    private var mainPanelView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(InterfaceStyle.muted)
                    TextField("搜索全部命令名称", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清空搜索")
                    }
                }
                .modifier(ToolbarSearchStyle(focused: searchFocused))
                Button {
                    clearDragState()
                    let defaultGroup: String?
                    if !isSearching, case .named(let name) = effectiveSelection { defaultGroup = name }
                    else { defaultGroup = nil }
                    editingCommand = Command(name: "", command: "", group: defaultGroup)
                } label: {
                    Label("添加命令", systemImage: "plus")
                }
                .buttonStyle(InterfaceButtonStyle(prominent: true))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(InterfaceStyle.material)

            Divider()

            subbarView

            Divider().opacity(0.5)

            commandListContent
        }
    }

    private var subbarView: some View {
        HStack(spacing: 8) {
            if isSearching {
                HStack(spacing: 8) {
                    Text("搜索结果").font(.system(size: 12.5, weight: .semibold)).fixedSize()
                    Text("跨全部分组 · \(searchMatchCount) 条")
                        .font(.system(size: 12))
                        .foregroundColor(InterfaceStyle.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button("返回当前分组") { searchText = "" }
                    .buttonStyle(CompactQuietButtonStyle())
                    .font(.system(size: 12))
                    .fixedSize()
            } else {
                let title: String = {
                    if case .named(let name) = effectiveSelection { return name }
                    return "未分组"
                }()
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                        .help(title)
                    Text("\(currentGroupCommands.count) 条")
                        .font(.system(size: 12))
                        .foregroundColor(InterfaceStyle.muted)
                        .fixedSize()
                }
                Spacer(minLength: 8)
                if case .named(let name) = effectiveSelection {
                    HStack(spacing: 4) {
                        Button("重命名分组") { startRenamingGroup(name) }
                            .buttonStyle(CompactQuietButtonStyle())
                            .font(.system(size: 12))
                            .fixedSize()
                        Button {
                            requestDeleteGroup(name)
                        } label: {
                            Text("删除分组").foregroundColor(InterfaceStyle.failure)
                        }
                        .buttonStyle(CompactQuietButtonStyle())
                        .font(.system(size: 12))
                        .fixedSize()
                    }
                } else {
                    Text("拖到左侧分组可快速归类")
                        .font(.system(size: 12))
                        .foregroundColor(InterfaceStyle.muted)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 36)
    }

    @ViewBuilder
    private var commandListContent: some View {
        if isSearching {
            if searchSections.isEmpty {
                emptyState(
                    title: "没有匹配的命令",
                    detail: "试试其他名称，或清空搜索。",
                    buttonTitle: "清空搜索",
                    action: { searchText = "" }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchSections) { section in
                            Text(section.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(InterfaceStyle.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 18)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                            ForEach(section.commands) { command in
                                commandRow(command, allowDrag: false)
                            }
                        }
                    }
                }
            }
        } else if currentGroupCommands.isEmpty {
            let groupLabel: String = {
                if case .named(let name) = effectiveSelection { return "「\(name)」" }
                return "未分组"
            }()
            emptyState(
                title: "\(groupLabel)还没有命令",
                detail: "可直接从其他分组拖入命令，或点击右上角添加命令。",
                buttonTitle: "添加命令",
                action: {
                    clearDragState()
                    let defaultGroup: String?
                    if case .named(let name) = effectiveSelection { defaultGroup = name }
                    else { defaultGroup = nil }
                    editingCommand = Command(name: "", command: "", group: defaultGroup)
                }
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(currentGroupCommands) { command in
                        commandRow(command, allowDrag: true)
                    }
                }
            }
        }
    }

    private func emptyState(title: String, detail: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Text("›_").font(.system(size: 30, design: .monospaced)).opacity(0.55)
            Text(title).font(.system(size: 15, weight: .medium)).foregroundColor(InterfaceStyle.text).multilineTextAlignment(.center)
            Text(detail).font(.system(size: 12)).multilineTextAlignment(.center)
            Button(buttonTitle, action: action)
        }
        .padding(.horizontal, 24)
        .buttonStyle(InterfaceButtonStyle())
        .foregroundColor(InterfaceStyle.muted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commandRow(_ command: Command, allowDrag: Bool) -> some View {
        let isHovered = hoveredCommandID == command.id
        let isDropTarget = dropReorderCommandID == command.id

        let row = HStack(spacing: 10) {
            if allowDrag {
                dragGrip(visible: isHovered)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(command.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    if command.autoExecute {
                        Text("自动执行")
                            .font(.system(size: 11))
                            .foregroundColor(InterfaceStyle.muted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(InterfaceStyle.subtle)
                            .cornerRadius(4)
                    }
                }
                Text(command.command)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(InterfaceStyle.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                clearDragState()
                editingCommand = command
            } label: {
                Text("编辑")
            }
            .buttonStyle(CommandRowButtonStyle(revealed: isHovered))
        }
        .padding(.leading, allowDrag ? 14 : 18)
        .padding(.trailing, 18)
        .frame(height: 56)
        .background(isHovered ? InterfaceStyle.subtle : Color.clear)
        .overlay(alignment: commandReorderAlignment(for: command.id)) {
            if isDropTarget {
                InterfaceStyle.selectedText.frame(height: 2)
            }
        }
        .overlay(alignment: .bottom) { InterfaceStyle.line.opacity(0.32).frame(height: 1) }
        .onHover { hovered in
            if hovered { hoveredCommandID = command.id }
            else if hoveredCommandID == command.id { hoveredCommandID = nil }
        }

        return Group {
            if allowDrag {
                row
                    .onDrag {
                        draggingItem = .command(command.id)
                        return Self.makeDragProvider("command:\(command.id.uuidString)")
                    }
                    .onDrop(
                        of: [Self.dragItemUTType],
                        delegate: CommandRowDropDelegate(
                            dragUTType: Self.dragItemUTType,
                            targetCommandID: command.id,
                            draggingItem: $draggingItem,
                            dropReorderCommandID: $dropReorderCommandID,
                            manager: manager,
                            onClearDrag: clearDragState
                        )
                    )
            } else {
                row
            }
        }
    }

    private func dragGrip(visible: Bool) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(InterfaceStyle.muted)
            .opacity(visible ? 0.85 : 0.3)
            .frame(width: 14)
    }

    private static func makeDragProvider(_ payload: String) -> NSItemProvider {
        let provider = NSItemProvider()
        let data = Data(payload.utf8)
        provider.registerDataRepresentation(forTypeIdentifier: dragItemUTType.identifier, visibility: .ownProcess) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    // MARK: - 交互动作

    private func selectGroup(_ group: SelectedGroup) {
        clearDragState()
        if let oldName = renamingGroup { commitRename(oldName: oldName) }
        if isCreatingGroup { commitNewGroup() }
        selectedGroup = group
        if !searchText.isEmpty { searchText = "" }
    }

    private func startCreatingGroup() {
        clearDragState()
        if let oldName = renamingGroup { commitRename(oldName: oldName) }
        newGroupDraft = ""
        isCreatingGroup = true
        DispatchQueue.main.async { newGroupFieldFocused = true }
    }

    private func commitNewGroup() {
        guard isCreatingGroup else { return }
        let candidate = newGroupDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        isCreatingGroup = false
        newGroupDraft = ""
        guard !candidate.isEmpty else { return }
        if manager.addGroup(candidate) {
            selectedGroup = .named(candidate)
        }
    }

    private func cancelCreatingGroup() {
        isCreatingGroup = false
        newGroupDraft = ""
    }

    private func startRenamingGroup(_ name: String) {
        clearDragState()
        if isCreatingGroup { commitNewGroup() }
        renameDraft = name
        renamingGroup = name
        DispatchQueue.main.async { renameFieldFocused = true }
    }

    private func commitRename(oldName: String) {
        guard renamingGroup == oldName else { return }
        let candidate = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        renamingGroup = nil
        renameDraft = ""
        guard !candidate.isEmpty, candidate != oldName else { return }
        if manager.renameGroup(oldName, to: candidate) {
            if selectedGroup == .named(oldName) {
                selectedGroup = .named(candidate)
            }
        }
    }

    private func cancelRenamingGroup() {
        renamingGroup = nil
        renameDraft = ""
    }

    private func requestDeleteGroup(_ name: String) {
        clearDragState()
        pendingDeleteGroup = name
        showingDeleteGroupConfirmation = true
    }

    private func dissolveGroup(_ name: String) {
        if manager.dissolveGroup(name), selectedGroup == .named(name) {
            selectedGroup = nil
        }
    }

    private func clearDragState() {
        draggingItem = nil
        dropReorderGroup = nil
        dropReceiveGroup = nil
        dropReorderCommandID = nil
    }

    // MARK: - Drop Delegates（仅接受本进程私有 UTType，隔绝外部文本拖放）

    private struct SidebarGroupDropDelegate: DropDelegate {
        let dragUTType: UTType
        let targetGroup: String
        @Binding var draggingItem: DragItem?
        @Binding var dropReorderGroup: String?
        @Binding var dropReceiveGroup: SelectedGroup?
        let manager: CommandsManager
        let onClearDrag: () -> Void

        func validateDrop(info: DropInfo) -> Bool {
            guard info.hasItemsConforming(to: [dragUTType]) else { return false }
            switch draggingItem {
            case .group(let source):
                return source != targetGroup
            case .command(let id):
                guard let cmd = manager.commands.first(where: { $0.id == id }) else { return false }
                return CommandsManager.normalizedGroup(cmd.group) != targetGroup
            case .none:
                return false
            }
        }

        func dropEntered(info: DropInfo) {
            guard validateDrop(info: info) else { return }
            switch draggingItem {
            case .group(let source) where source != targetGroup:
                dropReceiveGroup = nil
                dropReorderGroup = targetGroup
            case .command(let id):
                if let cmd = manager.commands.first(where: { $0.id == id }),
                   CommandsManager.normalizedGroup(cmd.group) != targetGroup {
                    dropReorderGroup = nil
                    dropReceiveGroup = .named(targetGroup)
                }
            default:
                break
            }
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: validateDrop(info: info) ? .move : .forbidden)
        }

        func dropExited(info: DropInfo) {
            if dropReorderGroup == targetGroup { dropReorderGroup = nil }
            if dropReceiveGroup == .named(targetGroup) { dropReceiveGroup = nil }
        }

        func performDrop(info: DropInfo) -> Bool {
            defer { onClearDrag() }
            guard info.hasItemsConforming(to: [dragUTType]) else { return false }
            switch draggingItem {
            case .group(let source):
                return manager.moveGroup(source, to: targetGroup)
            case .command(let id):
                return manager.assignCommand(id, toGroup: targetGroup)
            case .none:
                return false
            }
        }
    }

    private struct UngroupedDropDelegate: DropDelegate {
        let dragUTType: UTType
        @Binding var draggingItem: DragItem?
        @Binding var dropReceiveGroup: SelectedGroup?
        let manager: CommandsManager
        let onClearDrag: () -> Void

        func validateDrop(info: DropInfo) -> Bool {
            guard info.hasItemsConforming(to: [dragUTType]),
                  case .command(let id) = draggingItem,
                  let cmd = manager.commands.first(where: { $0.id == id }) else { return false }
            return CommandsManager.normalizedGroup(cmd.group) != nil
        }

        func dropEntered(info: DropInfo) {
            if validateDrop(info: info) {
                dropReceiveGroup = .ungrouped
            }
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: validateDrop(info: info) ? .move : .forbidden)
        }

        func dropExited(info: DropInfo) {
            if dropReceiveGroup == .ungrouped { dropReceiveGroup = nil }
        }

        func performDrop(info: DropInfo) -> Bool {
            defer { onClearDrag() }
            guard info.hasItemsConforming(to: [dragUTType]),
                  case .command(let id) = draggingItem else { return false }
            return manager.assignCommand(id, toGroup: nil)
        }
    }

    private struct CommandRowDropDelegate: DropDelegate {
        let dragUTType: UTType
        let targetCommandID: UUID
        @Binding var draggingItem: DragItem?
        @Binding var dropReorderCommandID: UUID?
        let manager: CommandsManager
        let onClearDrag: () -> Void

        func validateDrop(info: DropInfo) -> Bool {
            guard info.hasItemsConforming(to: [dragUTType]),
                  case .command(let sourceID) = draggingItem else { return false }
            return CommandsManager.canMoveCommand(sourceID, to: targetCommandID, in: manager.commands)
        }

        func dropEntered(info: DropInfo) {
            if validateDrop(info: info) {
                dropReorderCommandID = targetCommandID
            }
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: validateDrop(info: info) ? .move : .forbidden)
        }

        func dropExited(info: DropInfo) {
            if dropReorderCommandID == targetCommandID { dropReorderCommandID = nil }
        }

        func performDrop(info: DropInfo) -> Bool {
            defer { onClearDrag() }
            guard info.hasItemsConforming(to: [dragUTType]),
                  case .command(let sourceID) = draggingItem else { return false }
            return manager.moveCommand(sourceID, to: targetCommandID)
        }
    }
}
