import Foundation
import Combine

@MainActor
final class CommandsManager: ObservableObject {
    static let shared = CommandsManager()

    @Published private(set) var commands: [Command] = []
    @Published var lastError: AppError?

    private let settingsManager = AppSettingsManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadCommands()
        // 监听配置重载通知
        NotificationCenter.default.publisher(for: .settingsDidReload)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadCommands()
            }
            .store(in: &cancellables)
    }

    func loadCommands() {
        commands = settingsManager.settings.commands
    }

    func filteredCommands(by searchText: String) -> [Command] {
        guard !searchText.isEmpty else { return commands }
        return commands.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// 将命令按 group 分组，返回排序后的组名列表（nil 代表未分组，排在最后）
    func sortedGroupNames(from commands: [Command]) -> [String?] {
        var seen = Set<String?>()
        let appearanceOrder = commands.map(\.group).filter { seen.insert($0).inserted }

        if let order = AppSettingsManager.shared.settings.groupOrder {
            let ordered = order.filter { name in commands.contains(where: { $0.group == name }) }
            let remaining = appearanceOrder.compactMap { $0 }.filter { !order.contains($0) }
            let hasUngrouped = appearanceOrder.contains(nil)
            return ordered.map { $0 as String? } + remaining.map { $0 as String? } + (hasUngrouped ? [nil] : [])
        }

        return appearanceOrder
    }

    func addCommand(_ command: Command) {
        let originalCommands = commands
        commands.append(command)

        do {
            try settingsManager.saveCommands(commands)
        } catch {
            commands = originalCommands
            lastError = .configSaveFailed(error)
        }
    }

    func updateCommand(_ command: Command) {
        guard let index = commands.firstIndex(where: { $0.id == command.id }) else { return }

        let originalCommands = commands
        commands[index] = command

        do {
            try settingsManager.saveCommands(commands)
        } catch {
            commands = originalCommands
            lastError = .configSaveFailed(error)
        }
    }

    func deleteCommand(id: UUID) {
        guard let index = commands.firstIndex(where: { $0.id == id }) else { return }

        let originalCommands = commands
        commands.remove(at: index)

        do {
            try settingsManager.saveCommands(commands)
        } catch {
            commands = originalCommands
            lastError = .configSaveFailed(error)
        }
    }

    func reorderCommands(from source: IndexSet, to destination: Int) {
        let originalCommands = commands
        commands.move(fromOffsets: source, toOffset: destination)

        do {
            try settingsManager.saveCommands(commands)
        } catch {
            commands = originalCommands
            lastError = .configSaveFailed(error)
        }
    }

    func clearError() {
        lastError = nil
    }

    func importSettings(from url: URL) {
        let originalCommands = commands
        do {
            try settingsManager.importSettings(from: url)
            commands = settingsManager.settings.commands
        } catch {
            commands = originalCommands
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
