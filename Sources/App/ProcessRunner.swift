import Foundation

/// 进程运行编排：把一个进程跑到出 ExecutionResult。
/// 只认进程参数，对 Command 一无所知（Command → 进程的翻译在 CommandExecutor）；
/// 不落历史、不发通知，副作用归调用方
enum ProcessRunner {
    static func run(
        executableURL: URL,
        arguments: [String],
        workingDirectory: URL?,
        timeout: TimeInterval,
        completion: @escaping @MainActor (ExecutionResult) -> Void
    ) {
        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe
        process.executableURL = executableURL
        process.arguments = arguments
        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        // 超时和正常退出两个来源竞争，加锁保证回调只触发一次
        let finishOnce = Once()

        do {
            try process.run()

            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) { [weak process] in
                guard let process = process, process.isRunning else { return }
                finishOnce.run {
                    process.terminate()
                    let result = ExecutionResult.failed(.commandTimeout(seconds: Int(timeout.rounded(.up))))
                    Task { @MainActor in completion(result) }
                }
            }

            DispatchQueue.global(qos: .userInitiated).async {
                // 先排空管道再等退出：读阻塞到子进程退出关闭写端时自然返回 EOF。
                // 若先 waitUntilExit，输出超过管道缓冲（约 64KB）时子进程阻塞在写、
                // 父进程互等，卡满超时误报 commandTimeout 且输出丢弃
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                finishOnce.run {
                    let output = String(data: data, encoding: .utf8)

                    let result: ExecutionResult = process.terminationStatus == 0
                        ? .success(output)
                        : .exitedAbnormally(code: process.terminationStatus, output: output)

                    Task { @MainActor in completion(result) }
                }
            }
        } catch {
            finishOnce.run {
                let result = ExecutionResult.failed(.commandExecutionFailed(error.localizedDescription))
                Task { @MainActor in completion(result) }
            }
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
