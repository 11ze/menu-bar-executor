import Foundation
import Combine

@MainActor
final class CommandsManager: ObservableObject {
    static let shared = CommandsManager()

    @Published private(set) var commands: [Command] = []
    @Published var lastError: AppError?

    private let settingsManager = AppSettingsManager.shared
    private let executor = CommandExecutor.shared
    private let notificationManager = NotificationManager.shared
    private let history = ExecutionHistory.shared
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
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.command.localizedCaseInsensitiveContains(searchText)
        }
    }

    func execute(_ command: Command) {
        executor.execute(command: command) { [weak self] success, output in
            guard let self = self else { return }

            let record = ExecutionRecord(command: command, success: success, output: output)
            self.history.addRecord(record)

            if command.notification {
                if success {
                    self.notificationManager.showSuccess(commandName: command.name, output: output)
                } else {
                    let errorMsg = output ?? "未知错误"
                    self.notificationManager.showFailure(commandName: command.name, error: errorMsg, output: output)
                }
            }
        }
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
