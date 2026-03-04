import Foundation

final class CommandExecutor {
    static let shared = CommandExecutor()

    private init() {}

    func execute(command: Command, completion: @escaping (Bool, String?) -> Void) {
        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        // 使用系统默认 shell
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command.command]

        // 设置工作目录
        if let workingDir = command.workingDirectory {
            let expandedDir = NSString(string: workingDir).expandingTildeInPath
            process.currentDirectoryURL = URL(fileURLWithPath: expandedDir)
        }

        do {
            try process.run()

            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()

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
