import Foundation

/// 执行模式：决定这次执行是否计入执行历史、是否发系统通知
enum ExecutionMode {
    /// 用户主动触发（Enter / ⌘N）
    case userInitiated
    /// ⚡ 打开面板时自动执行，结果只内联显示在面板
    case auto
}

/// 一次命令运行的结局
enum ExecutionResult {
    /// 命令正常结束（退出码 0）
    case success(String?)
    /// 命令运行了但以非零退出码结束
    case exitedAbnormally(code: Int32, output: String?)
    /// 命令没跑起来：超时或启动失败
    case failed(AppError)
}

@MainActor
final class CommandExecutor {
    static let shared = CommandExecutor()

    private let defaultTimeout: TimeInterval = 30

    private init() {}

    /// 副作用决策：是否落账执行历史、是否发系统通知
    nonisolated static func sideEffects(command: Command, mode: ExecutionMode) -> (record: Bool, notify: Bool) {
        switch mode {
        case .userInitiated:
            return (true, command.notification)
        case .auto:
            return (false, false)
        }
    }

    /// 启动参数决策：默认加载完整 shell 配置（~/.zshrc + ~/.zprofile），
    /// 保证终端里能跑的命令（含 zshrc 函数、alias、export）这里也能跑；
    /// 直接执行跳过配置加载，换取 10ms 级启动，代价是函数/alias/zshrc 内环境变量不可用
    nonisolated static func launchArguments(for command: Command) -> [String] {
        command.directExecution ? ["-c", command.command] : ["-i", "-l", "-c", command.command]
    }

    func execute(
        command: Command,
        mode: ExecutionMode = .userInitiated,
        timeout customTimeout: TimeInterval? = nil,
        completion: (@MainActor (ExecutionResult) -> Void)? = nil
    ) {
        ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: Self.launchArguments(for: command),
            workingDirectory: command.workingDirectory.map {
                URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath)
            },
            timeout: customTimeout ?? defaultTimeout
        ) { result in
            self.finish(command: command, mode: mode, result: result, completion: completion)
        }
    }

    /// 回调与副作用统一出口（主线程）
    private func finish(
        command: Command,
        mode: ExecutionMode,
        result: ExecutionResult,
        completion: (@MainActor (ExecutionResult) -> Void)?
    ) {
        let effects = Self.sideEffects(command: command, mode: mode)

        if effects.record {
            ExecutionHistory.shared.addRecord(
                ExecutionRecord(command: command, success: isSuccessful(result), output: historyOutput(result))
            )
        }

        if effects.notify {
            switch result {
            case .success(let output):
                NotificationManager.shared.showSuccess(commandName: command.name, output: output)
            case .exitedAbnormally(_, let output):
                NotificationManager.shared.showFailure(
                    commandName: command.name, error: output ?? "未知错误", output: output
                )
            case .failed(let error):
                NotificationManager.shared.showFailure(
                    commandName: command.name, error: error.localizedDescription, output: nil
                )
            }
        }

        completion?(result)
    }

    private func isSuccessful(_ result: ExecutionResult) -> Bool {
        if case .success = result { return true }
        return false
    }

    /// 落账输出：命令跑了用命令输出，没跑起来用错误消息
    private func historyOutput(_ result: ExecutionResult) -> String? {
        switch result {
        case .success(let output), .exitedAbnormally(_, let output):
            return output
        case .failed(let error):
            return error.localizedDescription
        }
    }
}
