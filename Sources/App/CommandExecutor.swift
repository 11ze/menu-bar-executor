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

    func execute(
        command: Command,
        mode: ExecutionMode = .userInitiated,
        timeout customTimeout: TimeInterval? = nil,
        completion: (@MainActor (ExecutionResult) -> Void)? = nil
    ) {
        let timeout = customTimeout ?? defaultTimeout

        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        // 使用 interactive + login shell，确保加载 ~/.zshrc 和 ~/.zprofile
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-i", "-l", "-c", command.command]

        // 设置工作目录
        if let workingDir = command.workingDirectory {
            let expandedDir = NSString(string: workingDir).expandingTildeInPath
            process.currentDirectoryURL = URL(fileURLWithPath: expandedDir)
        }

        // 超时和正常退出两个来源竞争，加锁保证回调与副作用只触发一次
        let finishOnce = Once()

        do {
            try process.run()

            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) { [weak process] in
                guard let process = process, process.isRunning else { return }
                finishOnce.run {
                    process.terminate()
                    let result = ExecutionResult.failed(.commandTimeout(seconds: Int(timeout.rounded(.up))))
                    Task { @MainActor in
                        self.finish(command: command, mode: mode, result: result, completion: completion)
                    }
                }
            }

            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()

                finishOnce.run {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)

                    let result: ExecutionResult = process.terminationStatus == 0
                        ? .success(output)
                        : .exitedAbnormally(code: process.terminationStatus, output: output)

                    Task { @MainActor in
                        self.finish(command: command, mode: mode, result: result, completion: completion)
                    }
                }
            }
        } catch {
            finishOnce.run {
                let result = ExecutionResult.failed(.commandExecutionFailed(error.localizedDescription))
                Task { @MainActor in
                    self.finish(command: command, mode: mode, result: result, completion: completion)
                }
            }
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

/// 一次性执行守卫
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        lock.lock()
        let first = !done
        done = true
        lock.unlock()

        if first { body() }
    }
}
