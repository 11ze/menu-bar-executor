import Foundation
import Combine

/// 命令视图适配层：commands 镜像从 settings 直连派生，写入直通 settingsManager
@MainActor
final class CommandsManager: ObservableObject {
    static let shared = CommandsManager()

    @Published private(set) var commands: [Command] = []
    @Published var lastError: AppError?

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
    }

    // MARK: - 纯函数（过滤 / 分组排序）

    nonisolated static func filteredCommands(from commands: [Command], by searchText: String) -> [Command] {
        guard !searchText.isEmpty else { return commands }
        return commands.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// 将命令按 group 分组，返回排序后的组名列表（groupOrder 存在时 nil 代表未分组，排在最后）
    nonisolated static func sortedGroupNames(from commands: [Command], groupOrder: [String]?) -> [String?] {
        var seen = Set<String?>()
        let appearanceOrder = commands.map(\.group).filter { seen.insert($0).inserted }

        if let order = groupOrder {
            let ordered = order.filter { name in commands.contains(where: { $0.group == name }) }
            let remaining = appearanceOrder.compactMap { $0 }.filter { !order.contains($0) }
            let hasUngrouped = appearanceOrder.contains(nil)
            return ordered.map { $0 as String? } + remaining.map { $0 as String? } + (hasUngrouped ? [nil] : [])
        }

        return appearanceOrder
    }

    // MARK: - 命令写入（直通后镜像经 $settings 自动回流）

    func addCommand(_ command: Command) {
        settingsManager.saveCommands(commands + [command])
    }

    func updateCommand(_ command: Command) {
        guard let index = commands.firstIndex(where: { $0.id == command.id }) else { return }
        var updated = commands
        updated[index] = command
        settingsManager.saveCommands(updated)
    }

    func deleteCommand(id: UUID) {
        settingsManager.saveCommands(commands.filter { $0.id != id })
    }

    func reorderCommands(from source: IndexSet, to destination: Int) {
        var reordered = commands
        reordered.move(fromOffsets: source, toOffset: destination)
        settingsManager.saveCommands(reordered)
    }

    func clearError() {
        lastError = nil
    }

    // MARK: - 导入导出（真错误路径，失败落 lastError）

    func importSettings(from url: URL) {
        do {
            try settingsManager.importSettings(from: url)
        } catch {
            lastError = .configSaveFailed(error)
        }
    }

    func exportSettings(to url: URL) {
        do {
            try settingsManager.exportSettings(to: url)
        } catch {
            lastError = .configExportFailed(error)
        }
    }
}
