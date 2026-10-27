import Foundation

// MARK: - 面板列表项
enum PaletteItem: Identifiable, Equatable {
    case groupHeader(String)
    case command(Command, displayIndex: Int)

    var id: String {
        switch self {
        case .groupHeader(let name): return "header-\(name)"
        case .command(let cmd, _): return "cmd-\(cmd.id.uuidString)"
        }
    }

    var isCommand: Bool {
        if case .command = self { return true }
        return false
    }

    var command: Command? {
        if case .command(let cmd, _) = self { return cmd }
        return nil
    }
}

// MARK: - 面板列表快照
/// 由 commands + searchText + groupOrder 派生的纯值类型；
/// 选中索引随快照整体替换，视图只读
struct PaletteListModel: Equatable {
    let items: [PaletteItem]
    let selectedIndex: Int

    /// 搜索 / 命令变化时派生新快照，选中索引从 previousIndex 回绕调整
    static func derive(
        commands: [Command],
        searchText: String,
        groupOrder: [String]?,
        previousIndex: Int
    ) -> PaletteListModel {
        let filtered = CommandsManager.filteredCommands(from: commands, by: searchText)
        let items = buildItems(from: filtered, groupOrder: groupOrder)
        return PaletteListModel(
            items: items,
            selectedIndex: adjustedIndex(from: previousIndex, in: items)
        )
    }

    /// 选中重置（搜索文本变化时经 coordinator 调用）
    func updatingSelectedIndex(_ index: Int) -> PaletteListModel {
        PaletteListModel(items: items, selectedIndex: index)
    }

    /// ⌘N 快选反查：当前搜索结果前九条，分组标题不占编号。
    func command(atQuickSelectPosition position: Int) -> Command? {
        guard (1...9).contains(position) else { return nil }
        return items.first { item in
            if case .command(_, let index) = item { return index == position }
            return false
        }?.command
    }

    /// 向上导航：跳过组头，到顶返回 nil
    func movedUp() -> PaletteListModel? {
        var index = selectedIndex - 1
        while index >= 0 && !items[index].isCommand { index -= 1 }
        guard index >= 0 else { return nil }
        return updatingSelectedIndex(index)
    }

    /// 向下导航：跳过组头，到底返回 nil
    func movedDown() -> PaletteListModel? {
        var index = selectedIndex + 1
        while index < items.count && !items[index].isCommand { index += 1 }
        guard index < items.count else { return nil }
        return updatingSelectedIndex(index)
    }

    private static func buildItems(from commands: [Command], groupOrder: [String]?) -> [PaletteItem] {
        let grouped = Dictionary(grouping: commands, by: { $0.group?.isEmpty == true ? nil : $0.group })
        let sortedGroups = CommandsManager.sortedGroupNames(from: commands, groupOrder: groupOrder)

        var items: [PaletteItem] = []
        var displayIndex = 1
        for group in sortedGroups {
            guard let groupCommands = grouped[group] else { continue }
            if let groupName = group {
                items.append(.groupHeader(groupName))
            }
            for cmd in groupCommands {
                items.append(.command(cmd, displayIndex: displayIndex))
                displayIndex += 1
            }
        }
        return items
    }

    /// 选中索引调整：越界回 0；向后找最近命令项，找不到从头找，仍无则归零
    private static func adjustedIndex(from previous: Int, in items: [PaletteItem]) -> Int {
        guard !items.isEmpty else { return 0 }
        let start = (0..<items.count).contains(previous) ? previous : 0
        for i in start..<items.count where items[i].isCommand { return i }
        for i in 0..<start where items[i].isCommand { return i }
        return 0
    }
}
