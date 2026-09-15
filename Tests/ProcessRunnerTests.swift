import XCTest
@testable import MenuBarExecutor

/// ProcessRunner 接口测试：直跑真进程，不 mock。
/// 回归钉子：大输出命令不得死锁（曾因先 waitUntilExit 后读管道互等满超时）。
final class ProcessRunnerTests: XCTestCase {

    @MainActor
    func testRun_Echo_ReturnsSuccess() {
        let finished = expectation(description: "执行完成")

        ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["hello-runner"],
            workingDirectory: nil,
            timeout: 10
        ) { result in
            guard case let .success(output) = result else {
                return XCTFail("期望 .success，实际: \(result)")
            }
            XCTAssertEqual(output?.trimmingCharacters(in: .whitespacesAndNewlines), "hello-runner")
            finished.fulfill()
        }

        wait(for: [finished], timeout: 15)
    }

    @MainActor
    func testRun_NonZeroExit_ReturnsExitedAbnormally() {
        let finished = expectation(description: "执行完成")

        ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/false"),
            arguments: [],
            workingDirectory: nil,
            timeout: 10
        ) { result in
            guard case let .exitedAbnormally(code, _) = result else {
                return XCTFail("期望 .exitedAbnormally，实际: \(result)")
            }
            XCTAssertEqual(code, 1)
            finished.fulfill()
        }

        wait(for: [finished], timeout: 15)
    }

    @MainActor
    func testRun_LargeOutput_DoesNotDeadlock() {
        // 200KB 超过管道缓冲（约 64KB）：若先 waitUntilExit 后读管道，
        // 子进程阻塞在写、父进程互等，卡满超时误报 .commandTimeout
        let finished = expectation(description: "执行完成")

        ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/head"),
            arguments: ["-c", "200000", "/dev/zero"],
            workingDirectory: nil,
            timeout: 10
        ) { result in
            guard case .success = result else {
                return XCTFail("期望 .success（未超时即未死锁），实际: \(result)")
            }
            finished.fulfill()
        }

        wait(for: [finished], timeout: 15)
    }

    @MainActor
    func testRun_SleepTimeout_ReturnsFailedCommandTimeout() {
        let finished = expectation(description: "执行完成")

        ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["2"],
            workingDirectory: nil,
            timeout: 0.5
        ) { result in
            guard case .failed(let error) = result else {
                return XCTFail("期望 .failed，实际: \(result)")
            }
            guard case AppError.commandTimeout = error else {
                return XCTFail("期望 .commandTimeout，实际: \(error)")
            }
            finished.fulfill()
        }

        wait(for: [finished], timeout: 15)
    }

    @MainActor
    func testRun_WorkingDirectory_Respected() {
        let finished = expectation(description: "执行完成")

        ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/bin/pwd"),
            arguments: [],
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            timeout: 10
        ) { result in
            guard case let .success(output) = result else {
                return XCTFail("期望 .success，实际: \(result)")
            }
            // /tmp 是 /private/tmp 的符号链接，pwd 输出真实路径
            XCTAssertEqual(output?.trimmingCharacters(in: .whitespacesAndNewlines), "/private/tmp")
            finished.fulfill()
        }

        wait(for: [finished], timeout: 15)
    }

    @MainActor
    func testRun_NonexistentExecutable_ReturnsFailedExecution() {
        let finished = expectation(description: "执行完成")

        ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/nonexistent/executable"),
            arguments: [],
            workingDirectory: nil,
            timeout: 10
        ) { result in
            guard case .failed = result else {
                return XCTFail("期望 .failed，实际: \(result)")
            }
            finished.fulfill()
        }

        wait(for: [finished], timeout: 15)
    }
}
