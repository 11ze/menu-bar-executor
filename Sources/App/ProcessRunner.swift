import Foundation

/// 同时等待进程退出与输出结束；期限覆盖整个执行，超时后释放读取资源。
enum ProcessRunner {
    static func run(
        executableURL: URL,
        arguments: [String],
        workingDirectory: URL?,
        timeout: TimeInterval,
        completion: @escaping @MainActor (ExecutionResult) -> Void
    ) {
        let run = ProcessRun(completion: completion)
        run.process.executableURL = executableURL
        run.process.arguments = arguments
        run.process.currentDirectoryURL = workingDirectory
        run.start(timeout: timeout)
    }
}

private final class ProcessRun: @unchecked Sendable {
    let process = Process()
    private let pipe = Pipe()
    private let queue = DispatchQueue(label: "com.menu-bar-executor.process")
    private let completion: @MainActor (ExecutionResult) -> Void
    private var reader: DispatchSourceRead?
    private var timer: DispatchSourceTimer?
    private var data = Data()
    private var exitCode: Int32?
    private var reachedEOF = false
    private var finished = false

    init(completion: @escaping @MainActor (ExecutionResult) -> Void) {
        self.completion = completion
        process.standardOutput = pipe
        process.standardError = pipe
    }

    func start(timeout: TimeInterval) {
        queue.async {
            let handle = self.pipe.fileHandleForReading
            let fd = handle.fileDescriptor
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
            let reader = DispatchSource.makeReadSource(fileDescriptor: fd, queue: self.queue)
            reader.setEventHandler { self.readOutput() }
            reader.setCancelHandler { try? handle.close() }
            self.reader = reader
            reader.resume()

            self.process.terminationHandler = { process in
                self.queue.async {
                    self.exitCode = process.terminationStatus
                    self.completeIfReady()
                }
            }

            do {
                try self.process.run()
                self.pipe.fileHandleForWriting.closeFile()
                let timer = DispatchSource.makeTimerSource(queue: self.queue)
                timer.schedule(deadline: .now() + timeout)
                timer.setEventHandler {
                    guard !self.finished else { return }
                    // Foundation 为子进程建立独立进程组；同时终止仍持有管道的组内子进程。
                    kill(-self.process.processIdentifier, SIGKILL)
                    if self.process.isRunning { kill(self.process.processIdentifier, SIGKILL) }
                    self.finish(.failed(.commandTimeout(seconds: Int(timeout.rounded(.up)))))
                }
                self.timer = timer
                timer.resume()
            } catch {
                self.pipe.fileHandleForWriting.closeFile()
                self.finish(.failed(.commandExecutionFailed(error.localizedDescription)))
            }
        }
    }

    private func readOutput() {
        guard !finished else { return }
        var buffer = [UInt8](repeating: 0, count: 16_384)
        for _ in 0..<64 {
            let count = read(pipe.fileHandleForReading.fileDescriptor, &buffer, buffer.count)
            if count > 0 {
                data.append(contentsOf: buffer.prefix(count))
            } else if count == 0 {
                reachedEOF = true
                reader?.cancel()
                completeIfReady()
                return
            } else if errno == EINTR {
                continue
            } else if errno == EAGAIN {
                return
            } else {
                finish(.failed(.commandExecutionFailed(String(cString: strerror(errno)))))
                return
            }
        }
    }

    private func completeIfReady() {
        guard reachedEOF, let exitCode else { return }
        let output = String(data: data, encoding: .utf8)
        finish(exitCode == 0 ? .success(output) : .exitedAbnormally(code: exitCode, output: output))
    }

    private func finish(_ result: ExecutionResult) {
        guard !finished else { return }
        finished = true
        reader?.cancel()
        reader = nil
        timer?.cancel()
        timer = nil
        process.terminationHandler = nil
        Task { @MainActor [completion] in completion(result) }
    }
}
