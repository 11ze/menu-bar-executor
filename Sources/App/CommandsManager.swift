import Foundation
import Combine

@MainActor
final class CommandsManager: ObservableObject {
    static let shared = CommandsManager()

    @Published private(set) var commands: [Command] = []

    private let configLoader = ConfigLoader.shared
    private let executor = CommandExecutor.shared
    private let notificationManager = NotificationManager.shared

    private init() {
        print("[CommandsManager] 初始化")
        loadCommands()
    }

    func loadCommands() {
        print("[CommandsManager] 开始加载配置")
        configLoader.ensureConfigDirectoryExists()
        commands = configLoader.loadConfig()
        print("[CommandsManager] 加载了 \(commands.count) 个命令")
    }

    func reload() {
        loadCommands()
        notificationManager.showReloadSuccess()
    }

    func execute(_ command: Command) {
        executor.execute(command: command) { [weak self] success, output in
            guard let self = self else { return }

            if command.notification {
                if success {
                    self.notificationManager.showSuccess(commandName: command.name)
                } else {
                    let errorMsg = output ?? "未知错误"
                    self.notificationManager.showFailure(commandName: command.name, error: errorMsg)
                }
            }
        }
    }
}
