import Foundation

/// 进程运行句柄：允许调用方主动终止尚未完成的进程组。
final class ProcessHandle: @unchecked Sendable {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

private final class CancellationState: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

/// 同时等待进程退出与输出结束；期限覆盖整个执行，超时或取消后释放读取资源。
enum ProcessRunner {
    static let defaultMaxOutputBytes = 256 * 1024

    @discardableResult
    static func run(
        executableURL: URL,
        arguments: [String],
        workingDirectory: URL?,
        timeout: TimeInterval,
        maxOutputBytes: Int = defaultMaxOutputBytes,
        completion: @escaping @MainActor (ExecutionResult) -> Void
    ) -> ProcessHandle {
        let cancellationState = CancellationState()
        let run = ProcessRun(
            maxOutputBytes: maxOutputBytes,
            cancellationState: cancellationState,
            completion: completion
        )
        run.process.executableURL = executableURL
        run.process.arguments = arguments
        run.process.currentDirectoryURL = workingDirectory
        run.start(timeout: timeout)
        return ProcessHandle { [weak run] in
            cancellationState.cancel()
            run?.cancel()
        }
    }
}

private final class ProcessRun: @unchecked Sendable {
    let process = Process()
    private let pipe = Pipe()
    private let queue = DispatchQueue(label: "com.menu-bar-executor.process")
    private let maxOutputBytes: Int
    private let cancellationState: CancellationState
    private let completion: @MainActor (ExecutionResult) -> Void
    private var reader: DispatchSourceRead?
    private var timer: DispatchSourceTimer?
    private var data = Data()
    private var outputTruncated = false
    private var exitCode: Int32?
    private var reachedEOF = false
    private var finished = false

    init(
        maxOutputBytes: Int,
        cancellationState: CancellationState,
        completion: @escaping @MainActor (ExecutionResult) -> Void
    ) {
        self.maxOutputBytes = max(0, maxOutputBytes)
        self.cancellationState = cancellationState
        self.completion = completion
        process.standardOutput = pipe
        process.standardError = pipe
    }

    func start(timeout: TimeInterval) {
        queue.async {
            guard !self.finished, !self.cancellationState.isCancelled else {
                self.cleanup()
                return
            }
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
                    self.terminateProcessGroup()
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

    func cancel() {
        queue.async {
            guard !self.finished else { return }
            self.terminateProcessGroup()
            self.cleanup()
        }
    }

    private func terminateProcessGroup() {
        let pid = process.processIdentifier
        guard pid > 0 else { return }
        // Foundation 为子进程建立独立进程组；同时终止仍持有管道的组内子进程。
        kill(-pid, SIGKILL)
        if process.isRunning { kill(pid, SIGKILL) }
    }

    private func readOutput() {
        guard !finished else { return }
        var buffer = [UInt8](repeating: 0, count: 16_384)
        for _ in 0..<64 {
            let count = read(pipe.fileHandleForReading.fileDescriptor, &buffer, buffer.count)
            if count > 0 {
                let remaining = maxOutputBytes - data.count
                if remaining > 0 {
                    let take = min(count, remaining)
                    data.append(contentsOf: buffer.prefix(take))
                    if count > remaining { outputTruncated = true }
                } else {
                    outputTruncated = true
                }
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
                terminateProcessGroup()
                finish(.failed(.commandExecutionFailed(String(cString: strerror(errno)))))
                return
            }
        }
    }

    private func completeIfReady() {
        guard !finished, reachedEOF, let exitCode else { return }
        let slice = outputTruncated ? Self.trimmedTrailingIncompleteUTF8(data) : data
        var output = String(decoding: slice, as: UTF8.self)
        if outputTruncated {
            output = output.isEmpty ? "…（输出已截断）" : output + "\n…（输出已截断）"
        }
        finish(exitCode == 0 ? .success(output) : .exitedAbnormally(code: exitCode, output: output))
    }

    /// 字节上限截断可能劈裂末尾多字节 UTF-8 序列；向前回退到完整标量边界。
    private static func trimmedTrailingIncompleteUTF8(_ data: Data) -> Data {
        guard !data.isEmpty else { return data }
        var start = data.count - 1
        var continuations = 0
        while start > 0 && (data[start] & 0xC0) == 0x80 && continuations < 3 {
            start -= 1
            continuations += 1
        }
        let lead = data[start]
        let expectedLength: Int
        if lead < 0x80 {
            expectedLength = 1
        } else if (lead & 0xE0) == 0xC0 {
            expectedLength = 2
        } else if (lead & 0xF0) == 0xE0 {
            expectedLength = 3
        } else if (lead & 0xF8) == 0xF0 {
            expectedLength = 4
        } else {
            return data
        }
        return data.count - start < expectedLength ? data.prefix(start) : data
    }

    private func cleanup() {
        finished = true
        reader?.cancel()
        reader = nil
        timer?.cancel()
        timer = nil
        process.terminationHandler = nil
        data.removeAll(keepingCapacity: false)
    }

    private func finish(_ result: ExecutionResult) {
        guard !finished else { return }
        cleanup()
        guard !cancellationState.isCancelled else { return }
        let state = cancellationState
        Task { @MainActor [completion] in
            guard !state.isCancelled else { return }
            completion(result)
        }
    }
}
