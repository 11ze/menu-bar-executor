import XCTest
@testable import MenuBarExecutor

final class CommandExecutorTests: XCTestCase {

    // MARK: - 副作用决策

    func testSideEffects_UserInitiated_NotificationOn() {
        let command = Command(name: "测试", command: "echo hi", notification: true)
        let effects = CommandExecutor.sideEffects(command: command, mode: .userInitiated)

        XCTAssertTrue(effects.record, "用户主动执行计入执行历史")
        XCTAssertTrue(effects.notify, "notification 开启时发系统通知")
    }

    func testSideEffects_UserInitiated_NotificationOff() {
        let command = Command(name: "测试", command: "echo hi", notification: false)
        let effects = CommandExecutor.sideEffects(command: command, mode: .userInitiated)

        XCTAssertTrue(effects.record)
        XCTAssertFalse(effects.notify)
    }

    func testSideEffects_Auto_NotificationOn() {
        let command = Command(name: "测试", command: "echo hi", notification: true, autoExecute: true)
        let effects = CommandExecutor.sideEffects(command: command, mode: .auto)

        XCTAssertFalse(effects.record, "⚡ 自动执行不计入执行历史")
        XCTAssertFalse(effects.notify, "面板已内联展示结果，不发系统通知")
    }

    func testSideEffects_Auto_NotificationOff() {
        let command = Command(name: "测试", command: "echo hi", notification: false, autoExecute: true)
        let effects = CommandExecutor.sideEffects(command: command, mode: .auto)

        XCTAssertFalse(effects.record)
        XCTAssertFalse(effects.notify)
    }

    // MARK: - 启动参数

    func testLaunchArguments_Default_UsesInteractiveLoginShell() {
        let command = Command(name: "默认", command: "echo hi")
        XCTAssertEqual(
            CommandExecutor.launchArguments(for: command),
            ["-i", "-l", "-c", "echo hi"],
            "默认加载 ~/.zshrc 和 ~/.zprofile，保证终端里能跑的命令这里也能跑"
        )
    }

    func testLaunchArguments_DirectExecution_UsesLoginShell() {
        let command = Command(name: "直接执行", command: "echo hi", directExecution: true)
        XCTAssertEqual(
            CommandExecutor.launchArguments(for: command),
            ["-l", "-c", "echo hi"],
            "直接执行用 login shell：/etc/zprofile 的 path_helper 重建 PATH，登录项自启时也能找到 /usr/local/bin 等路径"
        )
    }

    // MARK: - 集成：三态执行结果（真 Process，auto 模式不落账不发通知）

    @MainActor
    func testExecute_Echo_ReturnsSuccess() {
        let command = Command(name: "回声", command: "echo hello-tdd", notification: false)
        let finished = expectation(description: "执行完成")

        CommandExecutor.shared.execute(command: command, mode: .auto) { result in
            guard case let .success(output) = result else {
                return XCTFail("期望 .success，实际: \(result)")
            }
            XCTAssertEqual(
                output?.trimmingCharacters(in: .whitespacesAndNewlines),
                "hello-tdd"
            )
            finished.fulfill()
        }

        wait(for: [finished], timeout: 10)
    }

    @MainActor
    func testExecute_NonZeroExit_ReturnsExitedAbnormally() {
        let command = Command(name: "失败命令", command: "echo err-msg; exit 1", notification: false)
        let finished = expectation(description: "执行完成")

        CommandExecutor.shared.execute(command: command, mode: .auto) { result in
            guard case let .exitedAbnormally(code, output) = result else {
                return XCTFail("期望 .exitedAbnormally，实际: \(result)")
            }
            XCTAssertEqual(code, 1)
            XCTAssertEqual(
                output?.trimmingCharacters(in: .whitespacesAndNewlines),
                "err-msg"
            )
            finished.fulfill()
        }

        wait(for: [finished], timeout: 10)
    }

    @MainActor
    func testExecute_SleepTimeout_ReturnsFailedCommandTimeout() {
        let command = Command(name: "长命令", command: "sleep 2", notification: false)
        let finished = expectation(description: "执行完成")

        CommandExecutor.shared.execute(command: command, mode: .auto, timeout: 0.5) { result in
            guard case .failed(let error) = result else {
                return XCTFail("期望 .failed，实际: \(result)")
            }
            guard case AppError.commandTimeout = error else {
                return XCTFail("期望 .commandTimeout，实际: \(error)")
            }
            finished.fulfill()
        }

        wait(for: [finished], timeout: 10)
    }

    // MARK: - 集成：userInitiated 副作用链路（注入内存假件，不写真历史、不发系统通知）

    @MainActor
    private final class HistorySpy: ExecutionHistoryRecording {
        var records: [ExecutionRecord] = []
        func addRecord(_ record: ExecutionRecord) { records.append(record) }
    }

    @MainActor
    private final class NotifierSpy: ExecutionNotifying {
        var successes: [String] = []
        var failures: [String] = []

        func showSuccess(commandName: String, output: String?) {
            successes.append(commandName)
        }

        func showFailure(commandName: String, error: String, output: String?) {
            failures.append(commandName)
        }
    }

    /// userInitiated 成功：落执行历史（success 标记 + 输出）且 notification 开启时发通知
    @MainActor
    func testExecute_UserInitiatedSuccess_RecordsAndNotifies() {
        let history = HistorySpy()
        let notifier = NotifierSpy()
        let executor = CommandExecutor(history: history, notifier: notifier)
        let command = Command(name: "回声", command: "echo side-effect", notification: true)
        let finished = expectation(description: "执行完成")

        executor.execute(command: command, mode: .userInitiated) { result in
            guard case .success = result else {
                return XCTFail("期望 .success，实际: \(result)")
            }
            XCTAssertEqual(history.records.count, 1, "userInitiated 落执行历史")
            XCTAssertTrue(history.records[0].success)
            XCTAssertEqual(history.records[0].output?.trimmingCharacters(in: .whitespacesAndNewlines), "side-effect")
            XCTAssertEqual(notifier.successes, ["回声"], "notification 开启时发系统通知")
            XCTAssertTrue(notifier.failures.isEmpty)
            finished.fulfill()
        }

        wait(for: [finished], timeout: 10)
    }

    /// auto 模式：即使 notification 开启也不落账、不发通知（⚡ 结果只内联显示在面板）
    @MainActor
    func testExecute_AutoMode_HasNoSideEffects() {
        let history = HistorySpy()
        let notifier = NotifierSpy()
        let executor = CommandExecutor(history: history, notifier: notifier)
        let command = Command(name: "闪电", command: "echo auto", notification: true, autoExecute: true)
        let finished = expectation(description: "执行完成")

        executor.execute(command: command, mode: .auto) { _ in
            XCTAssertTrue(history.records.isEmpty, "⚡ 自动执行不计入执行历史")
            XCTAssertTrue(notifier.successes.isEmpty)
            XCTAssertTrue(notifier.failures.isEmpty)
            finished.fulfill()
        }

        wait(for: [finished], timeout: 10)
    }

    /// userInitiated 非零退出：落历史 success=false，通知走失败分支（命令输出即错误文案）
    @MainActor
    func testExecute_UserInitiatedNonZeroExit_RecordsFailureAndNotifies() {
        let history = HistorySpy()
        let notifier = NotifierSpy()
        let executor = CommandExecutor(history: history, notifier: notifier)
        let command = Command(name: "失败命令", command: "echo err-side; exit 1", notification: true)
        let finished = expectation(description: "执行完成")

        executor.execute(command: command, mode: .userInitiated) { result in
            guard case .exitedAbnormally = result else {
                return XCTFail("期望 .exitedAbnormally，实际: \(result)")
            }
            XCTAssertEqual(history.records.count, 1)
            XCTAssertFalse(history.records[0].success)
            XCTAssertEqual(history.records[0].output?.trimmingCharacters(in: .whitespacesAndNewlines), "err-side")
            XCTAssertEqual(notifier.failures, ["失败命令"])
            XCTAssertTrue(notifier.successes.isEmpty)
            finished.fulfill()
        }

        wait(for: [finished], timeout: 10)
    }
}
