import Foundation

final class CommandExecutor {
    static let shared = CommandExecutor()

    private let defaultTimeout: TimeInterval = 30

    private init() {}

    func execute(command: Command, completion: @escaping (Bool, String?) -> Void) {
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

        do {
            try process.run()

            // 超时处理
            var hasCompleted = false
            let timeout = defaultTimeout

            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeout) { [weak process] in
                guard let process = process, process.isRunning else { return }
                if !hasCompleted {
                    hasCompleted = true
                    process.terminate()
                    DispatchQueue.main.async {
                        completion(false, "命令执行超时（\(Int(timeout))秒）")
                    }
                }
            }

            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()

                guard !hasCompleted else { return }
                hasCompleted = true

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)

                DispatchQueue.main.async {
                    let success = process.terminationStatus == 0
                    completion(success, output)
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
}
