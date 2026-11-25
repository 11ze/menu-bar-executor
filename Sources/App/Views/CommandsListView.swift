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

    private var footerStats: (visible: Int, activeAuto: Int, totalAuto: Int) {
        let visible = CommandsManager.visibleCommands(from: manager.commands, visibility: manager.groupVisibility)
        let activeAuto = visible.filter(\.autoExecute).count
        let totalAuto = manager.commands.filter(\.autoExecute).count
        return (visible.count, activeAuto, totalAuto)
    }

    private func isGroupHidden(_ group: String?) -> Bool {
        manager.groupVisibility.isGroupHidden(group)
    }

    private func isGroupHidden(_ selection: SelectedGroup) -> Bool {
        switch selection {
        case .named(let name): return isGroupHidden(name)
        case .ungrouped: return isGroupHidden(nil)
        }
    }

    private func toggleGroupHidden(_ selection: SelectedGroup) {
        clearDragState()
        switch selection {
        case .named(let name):
            manager.setGroupHidden(name, hidden: !isGroupHidden(name))
        case .ungrouped:
            manager.setGroupHidden(nil, hidden: !isGroupHidden(nil))
        }
    }

    var body: some View {
        let stats = footerStats
        return GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    sidebarView
                        .frame(width: geometry.size.width < 720 ? 184 : 224)
                    Divider()
                    mainPanelView
                }
                Divider()
                HStack {
                    if !isSearching {
                        Text("拖动命令可组内排序，拖到左侧分组可跨组移动")
                    }
                    Spacer()
                    Text("共 \(manager.commands.count) 条 · 可见 \(stats.visible) 条 · 自动执行 \(stats.activeAuto)/\(stats.totalAuto) 生效")
                }
                .font(.system(size: 12))
                .foregroundColor(InterfaceStyle.muted)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(InterfaceStyle.chrome)
            }
        }
        .onChange(of: searchText) { _ in clearDragState() }
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
        let isHidden = isGroupHidden(name)
        let count = manager.commands.filter { CommandsManager.normalizedGroup($0.group) == name }.count

        return Group {
            if renamingGroup == name {
                HStack(spacing: 6) {
                    dragGrip(visible: true)
                    InlineGroupTextField(
                        placeholder: "分组名称",
                        text: $renameDraft,
                        selectAllOnFocus: true,
                        onCommit: { commitRename(oldName: name) },
                        onCancel: { cancelRenamingGroup() }
                    )
                    .frame(height: 16)
                    .padding(.horizontal, 6)
                    .frame(height: 24)
                    .background(InterfaceStyle.surface)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(InterfaceStyle.selectedText, lineWidth: 1))
                    .cornerRadius(5)
                }
                .padding(.horizontal, 8)
                .frame(height: 34)
                .background(isActive ? InterfaceStyle.selection : Color.clear)
                .cornerRadius(7)
            } else {
                HStack(spacing: 5) {
                    Button {
                        selectGroup(key)
                    } label: {
                        HStack(spacing: 6) {
                            dragGrip(visible: isHovered || isActive)
                            Text(name)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(isActive || isReceiving ? InterfaceStyle.selectedRowText : InterfaceStyle.text)
                                .opacity(isHidden ? 0.52 : 1)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                        }
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isHidden ? "\(name)（已隐藏）" : name)

                    if isHovered {
                        HStack(spacing: 1) {
                            sidebarMiniButton(
                                systemImage: isHidden ? "eye.slash" : "eye",
                                label: isHidden ? "显示分组\(name)" : "隐藏分组\(name)",
                                highlighted: isHidden
                            ) {
                                toggleGroupHidden(key)
                            }
                            sidebarMiniButton(systemImage: "pencil", label: "重命名分组\(name)") {
                                startRenamingGroup(name)
                            }
                            sidebarMiniButton(systemImage: "xmark", label: "删除分组\(name)", destructive: true) {
                                requestDeleteGroup(name)
                            }
                        }
                    } else {
                        if isHidden {
                            sidebarMiniButton(
                                systemImage: "eye.slash",
                                label: "恢复显示分组\(name)",
                                highlighted: isActive
                            ) {
                                toggleGroupHidden(key)
                            }
                        }
                        Text("\(count)")
                            .font(.system(size: 11))
                            .foregroundColor(isActive ? InterfaceStyle.selectedRowText : InterfaceStyle.muted)
                            .opacity(isHidden ? 0.52 : (isActive ? 0.85 : 1))
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
            InlineGroupTextField(
                placeholder: "输入新分组名称",
                text: $newGroupDraft,
                selectAllOnFocus: false,
                onCommit: { commitNewGroup() },
                onCancel: { cancelCreatingGroup() }
            )
            .frame(height: 16)
            .padding(.horizontal, 6)
            .frame(height: 24)
            .background(InterfaceStyle.surface)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(InterfaceStyle.selectedText, lineWidth: 1))
            .cornerRadius(5)
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
    }

    private var ungroupedRow: some View {
        let key = SelectedGroup.ungrouped
        let isActive = !isSearching && effectiveSelection == key
        let isHovered = hoveredGroupKey == key
        let isReceiving = dropReceiveGroup == key
        let isHidden = isGroupHidden(nil)

        return HStack(spacing: 5) {
            Button {
                selectGroup(key)
            } label: {
                HStack(spacing: 6) {
                    Color.clear.frame(width: 14, height: 14)
                    Text("未分组")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(isActive || isReceiving ? InterfaceStyle.selectedRowText : InterfaceStyle.muted)
                        .opacity(isHidden ? 0.52 : 1)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isHovered {
                sidebarMiniButton(
                    systemImage: isHidden ? "eye.slash" : "eye",
                    label: isHidden ? "显示未分组" : "隐藏未分组",
                    highlighted: isHidden
                ) {
                    toggleGroupHidden(key)
                }
            } else {
                if isHidden {
                    sidebarMiniButton(
                        systemImage: "eye.slash",
                        label: "恢复显示未分组",
                        highlighted: isActive
                    ) {
                        toggleGroupHidden(key)
                    }
                }
                Text("\(ungroupedCount)")
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? InterfaceStyle.selectedRowText : InterfaceStyle.muted)
                    .opacity(isHidden ? 0.52 : (isActive ? 0.85 : 1))
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
        highlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(destructive ? InterfaceStyle.failure : (highlighted ? InterfaceStyle.selectedRowText : InterfaceStyle.muted))
                .frame(width: 21, height: 21)
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
                ToolbarSearchField(placeholder: "搜索全部命令名称", text: $searchText)
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

            if !isSearching && isGroupHidden(effectiveSelection) {
                groupHiddenBanner
                Divider()
            }

            commandListContent
        }
    }

    private var groupHiddenBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.slash")
                .font(.system(size: 11.5))
                .foregroundColor(InterfaceStyle.muted)
            Text("此分组已隐藏：组内命令不会在命令面板显示，自动执行已暂停（保留单条显隐设置）。")
                .font(.system(size: 12))
                .foregroundColor(InterfaceStyle.muted)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("恢复显示分组") {
                toggleGroupHidden(effectiveSelection)
            }
            .buttonStyle(InterfaceButtonStyle(height: 24))
            .font(.system(size: 11.5))
            .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(InterfaceStyle.subtle)
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
                let groupHidden = isGroupHidden(effectiveSelection)
                let hiddenCount = currentGroupCommands.filter(\.hidden).count
                let detailText: String = {
                    if groupHidden { return "\(currentGroupCommands.count) 条 · 分组已隐藏" }
                    if hiddenCount > 0 { return "\(currentGroupCommands.count) 条 · \(hiddenCount) 条隐藏" }
                    return "\(currentGroupCommands.count) 条"
                }()
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                        .help(title)
                    Text(detailText)
                        .font(.system(size: 12))
                        .foregroundColor(InterfaceStyle.muted)
                        .fixedSize()
                }
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    Button(groupHidden ? "显示分组" : "隐藏分组") {
                        toggleGroupHidden(effectiveSelection)
                    }
                    .buttonStyle(CompactQuietButtonStyle())
                    .font(.system(size: 12))
                    .fixedSize()
                    if case .named(let name) = effectiveSelection {
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
                            HStack(spacing: 6) {
                                Text(section.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(InterfaceStyle.muted)
                                if isGroupHidden(section.group) {
                                    Text("分组已隐藏")
                                        .font(.system(size: 11))
                                        .foregroundColor(InterfaceStyle.muted)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(InterfaceStyle.muted.opacity(0.14))
                                        .cornerRadius(4)
                                }
                                Spacer(minLength: 0)
                            }
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
        let groupHidden = isGroupHidden(command.group)
        let effectiveHidden = command.hidden || groupHidden

        let row = HStack(spacing: 10) {
            if allowDrag {
                dragGrip(visible: isHovered)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(command.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    if command.autoExecute {
                        let autoLabel = command.hidden ? "自动执行 · 已暂停" : (groupHidden ? "自动执行 · 随组暂停" : "自动执行")
                        let isPaused = command.hidden || groupHidden
                        Text(autoLabel)
                            .font(.system(size: 11))
                            .foregroundColor(InterfaceStyle.muted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(isPaused ? Color.clear : InterfaceStyle.subtle)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        isPaused ? InterfaceStyle.line : Color.clear,
                                        style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                                    )
                            )
                            .cornerRadius(4)
                            .fixedSize()
                    }
                    if command.hidden {
                        Text("已隐藏")
                            .font(.system(size: 11))
                            .foregroundColor(InterfaceStyle.muted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(InterfaceStyle.muted.opacity(0.14))
                            .cornerRadius(4)
                            .fixedSize()
                    }
                }
                Text(command.command)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(InterfaceStyle.muted)
                    .lineLimit(1)
            }
            .opacity(effectiveHidden ? 0.52 : 1)
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Button {
                    clearDragState()
                    manager.toggleCommandHidden(id: command.id)
                } label: {
                    Image(systemName: command.hidden ? "eye.slash" : "eye")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(CommandRowButtonStyle(revealed: isHovered, invisibleWhenIdle: !command.hidden))
                .accessibilityLabel(command.hidden ? "恢复显示「\(command.name)」" : "在命令面板中隐藏「\(command.name)」")
                .help(command.hidden ? "点击恢复在命令面板中显示" : "在命令面板中隐藏此命令")
                Button {
                    clearDragState()
                    editingCommand = command
                } label: {
                    Text("编辑")
                }
                .buttonStyle(CommandRowButtonStyle(revealed: isHovered))
            }
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

/// 原生行内分组输入框：规避 SwiftUI @FocusState 挂载期焦点回弹导致输入框闪退的问题，
/// 挂载到窗口后自动获取焦点（可选全选），仅在真正获得过焦点后失焦、或按回车时提交，按 Esc 取消。
struct InlineGroupTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let selectAllOnFocus: Bool
    let onCommit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit, onCancel: onCancel)
    }

    func makeNSView(context: Context) -> AutoFocusTextField {
        let field = AutoFocusTextField()
        field.placeholderString = placeholder
        field.stringValue = text
        field.font = .systemFont(ofSize: 12)
        field.textColor = NSColor(InterfaceStyle.text)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.lineBreakMode = .byTruncatingTail
        field.selectAllOnFocus = selectAllOnFocus
        field.onBecameFirstResponder = { [weak coordinator = context.coordinator] in
            coordinator?.hasFocused = true
        }
        field.onOutsideInteraction = { [weak field, weak coordinator = context.coordinator] in
            guard let field, let coordinator else { return }
            coordinator.commitFromOutsideInteraction(field: field)
        }
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: AutoFocusTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onCommit = onCommit
        context.coordinator.onCancel = onCancel
        field.placeholderString = placeholder
        field.selectAllOnFocus = selectAllOnFocus
        if field.currentEditor() == nil && field.stringValue != text {
            field.stringValue = text
        }
    }

    final class AutoFocusTextField: NSTextField {
        var selectAllOnFocus = false
        var onBecameFirstResponder: (() -> Void)?
        var onOutsideInteraction: (() -> Void)?
        private var didRequestInitialFocus = false
        private var mouseMonitor: Any?
        private var windowResignObserver: NSObjectProtocol?

        deinit {
            removeDismissMonitors()
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil {
                removeDismissMonitors()
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil, !didRequestInitialFocus else { return }
            didRequestInitialFocus = true
            requestInitialFocus(remainingAttempts: 3)
        }

        private func requestInitialFocus(remainingAttempts: Int) {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else { return }
                self.installDismissMonitors(for: window)
                if window.firstResponder === self || window.firstResponder === self.currentEditor() {
                    self.onBecameFirstResponder?()
                    return
                }
                if window.makeFirstResponder(self) {
                    self.onBecameFirstResponder?()
                    if self.selectAllOnFocus {
                        self.currentEditor()?.selectAll(nil)
                    }
                } else if remainingAttempts > 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                        self?.requestInitialFocus(remainingAttempts: remainingAttempts - 1)
                    }
                }
            }
        }

        private func installDismissMonitors(for window: NSWindow) {
            if mouseMonitor == nil {
                mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                    guard let self, let myWindow = self.window else { return event }
                    if event.window !== myWindow {
                        self.onOutsideInteraction?()
                        return event
                    }
                    let point = self.convert(event.locationInWindow, from: nil)
                    // 扩展外框 padding（左右 6pt、上下 4pt），避免点在输入框边框内缘时误提交
                    if !self.bounds.insetBy(dx: -6, dy: -4).contains(point) {
                        self.onOutsideInteraction?()
                    }
                    return event
                }
            }
            if windowResignObserver == nil {
                windowResignObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didResignKeyNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.onOutsideInteraction?()
                }
            }
        }

        func removeDismissMonitors() {
            if let monitor = mouseMonitor {
                NSEvent.removeMonitor(monitor)
                mouseMonitor = nil
            }
            if let observer = windowResignObserver {
                NotificationCenter.default.removeObserver(observer)
                windowResignObserver = nil
            }
        }

        override func becomeFirstResponder() -> Bool {
            let accepted = super.becomeFirstResponder()
            if accepted {
                onBecameFirstResponder?()
            }
            return accepted
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onCommit: () -> Void
        var onCancel: () -> Void
        var hasFocused = false
        private var didFinish = false

        init(text: Binding<String>, onCommit: @escaping () -> Void, onCancel: @escaping () -> Void) {
            self.text = text
            self.onCommit = onCommit
            self.onCancel = onCancel
        }

        func commitFromOutsideInteraction(field: AutoFocusTextField) {
            guard !didFinish else { return }
            didFinish = true
            field.removeDismissMonitors()
            if field.currentEditor() != nil {
                field.window?.makeFirstResponder(nil)
            }
            text.wrappedValue = field.stringValue
            onCommit()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                guard !didFinish else { return true }
                didFinish = true
                (control as? AutoFocusTextField)?.removeDismissMonitors()
                if let field = control as? NSTextField {
                    text.wrappedValue = field.stringValue
                }
                onCommit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                guard !didFinish else { return true }
                didFinish = true
                (control as? AutoFocusTextField)?.removeDismissMonitors()
                onCancel()
                return true
            }
            return false
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard hasFocused, !didFinish else { return }
            didFinish = true
            (notification.object as? AutoFocusTextField)?.removeDismissMonitors()
            if let field = notification.object as? NSTextField {
                text.wrappedValue = field.stringValue
            }
            onCommit()
        }
    }
}
