import Foundation
import Combine

@MainActor
final class CommandsManager: ObservableObject {
    static let shared = CommandsManager()

    @Published private(set) var commands: [Command] = []
    @Published var lastError: AppError?

    private let configLoader = ConfigLoader.shared
    private let executor = CommandExecutor.shared
    private let notificationManager = NotificationManager.shared
    private let history = ExecutionHistory.shared

    private init() {
        loadCommands()
    }

    func loadCommands() {
        configLoader.ensureConfigDirectoryExists()
        commands = configLoader.loadConfig()
    }

    func reload() {
        loadCommands()
        notificationManager.showReloadSuccess()
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
            try configLoader.saveConfig(commands)
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
            try configLoader.saveConfig(commands)
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
            try configLoader.saveConfig(commands)
        } catch {
            commands = originalCommands
            lastError = .configSaveFailed(error)
        }
    }

    func reorderCommands(from source: IndexSet, to destination: Int) {
        let originalCommands = commands
        commands.move(fromOffsets: source, toOffset: destination)

        do {
            try configLoader.saveConfig(commands)
        } catch {
            commands = originalCommands
            lastError = .configSaveFailed(error)
        }
    }

    func clearError() {
        lastError = nil
    }
}
