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

    func addCommand(_ command: Command) {
        commands.append(command)
        do {
            try configLoader.saveConfig(commands)
            print("[CommandsManager] 命令已添加: \(command.name)")
        } catch {
            print("[CommandsManager] 保存失败: \(error)")
        }
    }

    func updateCommand(_ command: Command) {
        if let index = commands.firstIndex(where: { $0.id == command.id }) {
            commands[index] = command
            do {
                try configLoader.saveConfig(commands)
                print("[CommandsManager] 命令已更新: \(command.name)")
            } catch {
                print("[CommandsManager] 保存失败: \(error)")
            }
        }
    }

    func deleteCommand(id: String) {
        if let index = commands.firstIndex(where: { $0.id == id }) {
            let command = commands[index]
            commands.remove(at: index)
            do {
                try configLoader.saveConfig(commands)
                print("[CommandsManager] 命令已删除: \(command.name)")
            } catch {
                print("[CommandsManager] 保存失败: \(error)")
            }
        }
    }
}
