import Foundation
import Combine

/// 已归一化的分组显隐快照，收口持久化层的 hiddenGroups + hideUngrouped 表示
struct GroupVisibility: Equatable {
    let hiddenGroups: Set<String>
    let hideUngrouped: Bool

    init(hiddenGroups: [String] = [], hideUngrouped: Bool = false) {
        self.hiddenGroups = Set(CommandsManager.normalizedHiddenGroups(hiddenGroups))
        self.hideUngrouped = hideUngrouped
    }

    func isGroupHidden(_ rawGroup: String?) -> Bool {
        guard let group = CommandsManager.normalizedGroup(rawGroup) else {
            return hideUngrouped
        }
        return hiddenGroups.contains(group)
    }

    func isCommandVisible(_ command: Command) -> Bool {
        !command.hidden && !isGroupHidden(command.group)
    }
}

/// 命令视图适配层：commands 与 groupVisibility 镜像从 settings 直连派生，写入直通 settingsManager
@MainActor
final class CommandsManager: ObservableObject {
    static let shared = CommandsManager()

    @Published private(set) var commands: [Command] = []
    @Published private(set) var groupVisibility = GroupVisibility()

    private let settingsManager = AppSettingsManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // 外部修改 / 导入 / 重载都经 $settings 到达，镜像无需额外同步链
        settingsManager.$settings
            .map(\.commands)
            .removeDuplicates()
            .sink { [weak self] commands in
                self?.commands = commands
            }
            .store(in: &cancellables)

        settingsManager.$settings
            .map { GroupVisibility(hiddenGroups: $0.hiddenGroups, hideUngrouped: $0.hideUngrouped) }
            .removeDuplicates()
            .sink { [weak self] visibility in
                self?.groupVisibility = visibility
            }
            .store(in: &cancellables)
    }

    // MARK: - 纯函数（过滤 / 分组排序）

    nonisolated static func normalizedGroup(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    nonisolated static func filteredCommands(from commands: [Command], by searchText: String) -> [Command] {
        guard !searchText.isEmpty else { return commands }
        return commands.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    nonisolated static func normalizedHiddenGroups(_ hiddenGroups: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in hiddenGroups {
            if let name = normalizedGroup(raw), seen.insert(name).inserted {
                result.append(name)
            }
        }
        return result
    }

    nonisolated static func isGroupHidden(
        _ rawGroup: String?,
        hiddenGroups: [String],
        hideUngrouped: Bool
    ) -> Bool {
        GroupVisibility(hiddenGroups: hiddenGroups, hideUngrouped: hideUngrouped).isGroupHidden(rawGroup)
    }

    nonisolated static func visibleCommands(
        from commands: [Command],
        visibility: GroupVisibility
    ) -> [Command] {
        commands.filter(visibility.isCommandVisible)
    }

    nonisolated static func visibleCommands(
        from commands: [Command],
        hiddenGroups: [String],
        hideUngrouped: Bool
    ) -> [Command] {
        visibleCommands(from: commands, visibility: GroupVisibility(hiddenGroups: hiddenGroups, hideUngrouped: hideUngrouped))
    }

    /// 清理已不存在于当前管理分组中的孤儿隐藏分组，防止 groupOrder == nil 时删空分组导致后续新建同名分组天生隐藏
    nonisolated static func prunedHiddenGroups(
        _ hiddenGroups: [String],
        commands: [Command],
        groupOrder: [String]?
    ) -> [String] {
        let validGroups = Set(managedGroupNames(from: commands, groupOrder: groupOrder))
        return normalizedHiddenGroups(hiddenGroups).filter { validGroups.contains($0) }
    }

    nonisolated static func settingGroupHidden(
        _ rawGroup: String,
        hidden: Bool,
        in hiddenGroups: [String]
    ) -> [String] {
        var normalized = normalizedHiddenGroups(hiddenGroups)
        guard let name = normalizedGroup(rawGroup) else { return normalized }
        if hidden {
            if !normalized.contains(name) {
                normalized.append(name)
            }
        } else {
            normalized.removeAll { $0 == name }
        }
        return normalized
    }

    nonisolated static func togglingCommandHidden(
        _ commandID: UUID,
        in commands: [Command]
    ) -> [Command]? {
        guard let index = commands.firstIndex(where: { $0.id == commandID }) else { return nil }
        var updated = commands
        updated[index].hidden.toggle()
        return updated
    }

    /// 将命令按 group 分组，返回排序后的组名列表（groupOrder 存在时 nil 代表未分组，排在最后）
    nonisolated static func sortedGroupNames(from commands: [Command], groupOrder: [String]?) -> [String?] {
        var seen = Set<String?>()
        let appearanceOrder = commands.map { normalizedGroup($0.group) }.filter { seen.insert($0).inserted }

        if let order = groupOrder {
            var seenOrdered = Set<String>()
            let ordered = order.compactMap { normalizedGroup($0) }.filter { name in
                seenOrdered.insert(name).inserted
                    && commands.contains(where: { normalizedGroup($0.group) == name })
            }
            let remaining = appearanceOrder.compactMap { $0 }.filter { !seenOrdered.contains($0) }
            let hasUngrouped = appearanceOrder.contains(nil)
            return ordered.map { $0 as String? } + remaining.map { $0 as String? } + (hasUngrouped ? [nil] : [])
        }

        return appearanceOrder
    }

    // MARK: - 命令写入（直通后镜像经 $settings 自动回流）

    /// 新建 / 编辑统一入口：按 id 判别身份（编辑器保存回调不再自行判别）
    @discardableResult
    func upsert(_ command: Command) -> Bool {
        let updatedCommands = Self.upserted(command, in: commands)
        let currentOrder = settingsManager.settings.groupOrder
        let nextOrder = Self.groupOrderAfterUpserting(command, in: commands, currentGroupOrder: currentOrder)
        let currentHidden = settingsManager.settings.hiddenGroups
        // 先按变更前快照清理孤儿隐藏项（防止新建分组撞上外部残留孤儿），再按变更后快照清理已删空分组
        let withoutStaleOrphans = Self.prunedHiddenGroups(currentHidden, commands: commands, groupOrder: currentOrder)
        let nextHidden = Self.prunedHiddenGroups(withoutStaleOrphans, commands: updatedCommands, groupOrder: nextOrder)
        if nextOrder != currentOrder || nextHidden != currentHidden {
            return settingsManager.updateCommandsAndGroups(
                commands: updatedCommands,
                groupOrder: nextOrder,
                hiddenGroups: nextHidden
            )
        }
        return settingsManager.saveCommands(updatedCommands)
    }

    /// 当已启用显式 groupOrder 且命令带入新命名分组时，将该分组追加到 groupOrder 末尾
    nonisolated static func groupOrderAfterUpserting(
        _ command: Command,
        in commands: [Command],
        currentGroupOrder: [String]?
    ) -> [String]? {
        guard let currentGroupOrder, let group = normalizedGroup(command.group) else {
            return currentGroupOrder
        }
        let existing = managedGroupNames(from: commands, groupOrder: currentGroupOrder)
        guard !existing.contains(group) else { return currentGroupOrder }
        return existing + [group]
    }

    /// id 已知则原位替换，未知则追加
    nonisolated static func upserted(_ command: Command, in commands: [Command]) -> [Command] {
        guard let index = commands.firstIndex(where: { $0.id == command.id }) else {
            return commands + [command]
        }
        var updated = commands
        updated[index] = command
        return updated
    }

    @discardableResult
    func deleteCommand(id: UUID) -> Bool {
        let updatedCommands = commands.filter { $0.id != id }
        let currentOrder = settingsManager.settings.groupOrder
        let currentHidden = settingsManager.settings.hiddenGroups
        let nextHidden = Self.prunedHiddenGroups(currentHidden, commands: updatedCommands, groupOrder: currentOrder)
        if nextHidden != currentHidden {
            return settingsManager.updateCommandsAndGroups(
                commands: updatedCommands,
                groupOrder: currentOrder,
                hiddenGroups: nextHidden
            )
        }
        return settingsManager.saveCommands(updatedCommands)
    }

    // MARK: - 分组管理（侧栏含空分组、拖拽排序、新建、重命名、解散）

    /// 设置页分组管理列表：保留 groupOrder 中新建的空分组，并按首现序补齐命令里新增的命名分组
    nonisolated static func managedGroupNames(from commands: [Command], groupOrder: [String]?) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        if let order = groupOrder {
            for raw in order {
                if let name = normalizedGroup(raw), seen.insert(name).inserted {
                    result.append(name)
                }
            }
        }
        for cmd in commands {
            if let group = normalizedGroup(cmd.group), seen.insert(group).inserted {
                result.append(group)
            }
        }
        return result
    }

    /// 将分组移动到目标分组的索引位置（上拖插在目标前、下拖插在目标后）
    nonisolated static func movingGroup(
        _ groupName: String,
        to targetGroup: String,
        from commands: [Command],
        groupOrder: [String]?
    ) -> [String]? {
        guard groupName != targetGroup else { return nil }
        var groups = managedGroupNames(from: commands, groupOrder: groupOrder)
        guard let fromIndex = groups.firstIndex(of: groupName),
              let toIndex = groups.firstIndex(of: targetGroup) else {
            return nil
        }
        let moved = groups.remove(at: fromIndex)
        groups.insert(moved, at: toIndex)
        return groups
    }

    nonisolated static func addingGroup(
        _ rawName: String,
        from commands: [Command],
        groupOrder: [String]?
    ) -> [String]? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        var groups = managedGroupNames(from: commands, groupOrder: groupOrder)
        guard !groups.contains(name) else { return nil }
        groups.append(name)
        return groups
    }

    nonisolated static func renamingGroup(
        _ oldName: String,
        to rawNewName: String,
        in commands: [Command],
        groupOrder: [String]?,
        hiddenGroups: [String] = []
    ) -> (commands: [Command], groupOrder: [String], hiddenGroups: [String])? {
        guard let normalizedOld = normalizedGroup(oldName),
              let newName = normalizedGroup(rawNewName),
              newName != normalizedOld else { return nil }
        var groups = managedGroupNames(from: commands, groupOrder: groupOrder)
        let existingGroupSet = Set(groups)
        guard let index = groups.firstIndex(of: normalizedOld), !groups.contains(newName) else { return nil }
        groups[index] = newName
        let updatedCommands = commands.map { cmd -> Command in
            guard normalizedGroup(cmd.group) == normalizedOld else { return cmd }
            var copy = cmd
            copy.group = newName
            return copy
        }
        let updatedHidden = normalizedHiddenGroups(
            normalizedHiddenGroups(hiddenGroups)
                .filter { existingGroupSet.contains($0) }
                .map { $0 == normalizedOld ? newName : $0 }
        )
        return (updatedCommands, groups, updatedHidden)
    }

    nonisolated static func dissolvingGroup(
        _ groupName: String,
        in commands: [Command],
        groupOrder: [String]?,
        hiddenGroups: [String] = []
    ) -> (commands: [Command], groupOrder: [String], hiddenGroups: [String])? {
        guard let normalizedTarget = normalizedGroup(groupName) else { return nil }
        var groups = managedGroupNames(from: commands, groupOrder: groupOrder)
        guard let index = groups.firstIndex(of: normalizedTarget) else { return nil }
        groups.remove(at: index)
        let updatedCommands = commands.map { cmd -> Command in
            guard normalizedGroup(cmd.group) == normalizedTarget else { return cmd }
            var copy = cmd
            copy.group = nil
            return copy
        }
        let updatedHidden = normalizedHiddenGroups(hiddenGroups).filter { $0 != normalizedTarget }
        return (updatedCommands, groups, updatedHidden)
    }

    /// 轻量只读校验：两条命令是否存在且同属一个分组，用于高频拖拽校验避免深拷贝
    nonisolated static func canMoveCommand(
        _ sourceID: UUID,
        to targetID: UUID,
        in commands: [Command]
    ) -> Bool {
        guard sourceID != targetID,
              let source = commands.first(where: { $0.id == sourceID }),
              let target = commands.first(where: { $0.id == targetID }) else {
            return false
        }
        return normalizedGroup(source.group) == normalizedGroup(target.group)
    }

    /// 组内命令拖拽重排：仅允许同组内移动，移至目标项当前位置（上拖插前、下拖插后）
    nonisolated static func movingCommand(
        _ sourceID: UUID,
        to targetID: UUID,
        in commands: [Command]
    ) -> [Command]? {
        guard sourceID != targetID,
              let fromIndex = commands.firstIndex(where: { $0.id == sourceID }),
              let toIndex = commands.firstIndex(where: { $0.id == targetID }) else {
            return nil
        }
        guard normalizedGroup(commands[fromIndex].group) == normalizedGroup(commands[toIndex].group) else {
            return nil
        }
        var reordered = commands
        let moved = reordered.remove(at: fromIndex)
        reordered.insert(moved, at: toIndex)
        return reordered
    }

    /// 跨组拖拽归类：修改目标命令的分组并将其追加到列表末尾，确保排在目标组最后
    nonisolated static func assigningCommand(
        _ commandID: UUID,
        toGroup targetGroup: String?,
        in commands: [Command]
    ) -> [Command]? {
        let normalizedTarget = normalizedGroup(targetGroup)
        guard let index = commands.firstIndex(where: { $0.id == commandID }) else { return nil }
        let currentGroup = normalizedGroup(commands[index].group)
        guard currentGroup != normalizedTarget else { return nil }
        var updated = commands
        var moved = updated.remove(at: index)
        moved.group = normalizedTarget
        updated.append(moved)
        return updated
    }

    @discardableResult
    func moveGroup(_ groupName: String, to targetGroup: String) -> Bool {
        guard let nextOrder = Self.movingGroup(
            groupName,
            to: targetGroup,
            from: commands,
            groupOrder: settingsManager.settings.groupOrder
        ) else { return false }
        return settingsManager.saveGroupOrder(nextOrder)
    }

    @discardableResult
    func addGroup(_ rawName: String) -> Bool {
        guard let nextOrder = Self.addingGroup(
            rawName,
            from: commands,
            groupOrder: settingsManager.settings.groupOrder
        ) else { return false }
        let currentHidden = settingsManager.settings.hiddenGroups
        let nextHidden = Self.settingGroupHidden(rawName, hidden: false, in: currentHidden)
        if nextHidden != currentHidden {
            return settingsManager.updateCommandsAndGroups(
                commands: commands,
                groupOrder: nextOrder,
                hiddenGroups: nextHidden
            )
        }
        return settingsManager.saveGroupOrder(nextOrder)
    }

    @discardableResult
    func renameGroup(_ oldName: String, to rawNewName: String) -> Bool {
        guard let result = Self.renamingGroup(
            oldName,
            to: rawNewName,
            in: commands,
            groupOrder: settingsManager.settings.groupOrder,
            hiddenGroups: settingsManager.settings.hiddenGroups
        ) else { return false }
        return settingsManager.updateCommandsAndGroups(
            commands: result.commands,
            groupOrder: result.groupOrder,
            hiddenGroups: result.hiddenGroups
        )
    }

    @discardableResult
    func dissolveGroup(_ groupName: String) -> Bool {
        guard let result = Self.dissolvingGroup(
            groupName,
            in: commands,
            groupOrder: settingsManager.settings.groupOrder,
            hiddenGroups: settingsManager.settings.hiddenGroups
        ) else { return false }
        return settingsManager.updateCommandsAndGroups(
            commands: result.commands,
            groupOrder: result.groupOrder,
            hiddenGroups: result.hiddenGroups
        )
    }

    @discardableResult
    func toggleCommandHidden(id: UUID) -> Bool {
        guard let updated = Self.togglingCommandHidden(id, in: commands) else { return false }
        return settingsManager.saveCommands(updated)
    }

    @discardableResult
    func setGroupHidden(_ group: String?, hidden: Bool) -> Bool {
        guard let groupName = Self.normalizedGroup(group) else {
            return settingsManager.setUngroupedHidden(hidden)
        }
        let next = Self.settingGroupHidden(groupName, hidden: hidden, in: settingsManager.settings.hiddenGroups)
        return settingsManager.saveHiddenGroups(next)
    }

    @discardableResult
    func moveCommand(_ sourceID: UUID, to targetID: UUID) -> Bool {
        guard let updated = Self.movingCommand(sourceID, to: targetID, in: commands) else { return false }
        return settingsManager.saveCommands(updated)
    }

    @discardableResult
    func assignCommand(_ commandID: UUID, toGroup targetGroup: String?) -> Bool {
        guard let updated = Self.assigningCommand(commandID, toGroup: targetGroup, in: commands) else { return false }
        let currentOrder = settingsManager.settings.groupOrder
        let currentHidden = settingsManager.settings.hiddenGroups
        let nextHidden = Self.prunedHiddenGroups(currentHidden, commands: updated, groupOrder: currentOrder)
        if nextHidden != currentHidden {
            return settingsManager.updateCommandsAndGroups(
                commands: updated,
                groupOrder: currentOrder,
                hiddenGroups: nextHidden
            )
        }
        return settingsManager.saveCommands(updated)
    }

    // MARK: - 导入导出（真错误路径，失败落 lastError）

    func importSettings(from url: URL) {
        do {
            try settingsManager.importSettings(from: url)
        } catch {
            settingsManager.lastError = .configSaveFailed(error)
        }
    }

    func exportSettings(to url: URL) {
        do {
            try settingsManager.exportSettings(to: url)
            settingsManager.lastError = nil
        } catch {
            settingsManager.lastError = .configExportFailed(error)
        }
    }
}
