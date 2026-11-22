import Combine
import XCTest
@testable import MenuBarExecutor

final class PaletteCoordinatorTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("palette-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDirectory)
    }

    private func writeSettings(_ settings: AppSettings, named name: String) throws -> URL {
        let url = tempDirectory.appendingPathComponent(name)
        try JSONEncoder().encode(settings).write(to: url)
        return url
    }

    @MainActor
    func testImportOnlyGroupOrder_UpdatesPaletteImmediately() throws {
        var settings = AppSettings()
        settings.commands = [
            Command(name: "a", command: "echo a", group: "A组"),
            Command(name: "b", command: "echo b", group: "B组"),
        ]
        settings.groupOrder = ["A组", "B组"]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        let coordinator = PaletteCoordinator(settingsManager: manager)
        XCTAssertEqual(coordinator.listModel.items.compactMap { $0.command?.name }, ["a", "b"])

        settings.groupOrder = ["B组", "A组"]
        try manager.importSettings(from: writeSettings(settings, named: "import.json"))

        XCTAssertEqual(coordinator.listModel.items.compactMap { $0.command?.name }, ["b", "a"])
    }

    @MainActor
    func testImportCommandsAndGroupOrder_FirstPublishedListUsesNewSnapshot() throws {
        var settings = AppSettings()
        settings.commands = [
            Command(name: "a", command: "echo a", group: "A组"),
            Command(name: "b", command: "echo b", group: "B组"),
        ]
        settings.groupOrder = ["A组", "B组"]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        let coordinator = PaletteCoordinator(settingsManager: manager)
        var firstPublishedNames: [String]?
        let subscription = coordinator.$listModel.dropFirst().prefix(1).sink { model in
            firstPublishedNames = model.items.compactMap { $0.command?.name }
        }
        defer { subscription.cancel() }

        settings.commands[0].name = "a-new"
        settings.groupOrder = ["B组", "A组"]
        try manager.importSettings(from: writeSettings(settings, named: "import.json"))

        XCTAssertEqual(firstPublishedNames, ["b", "a-new"])
        XCTAssertEqual(coordinator.listModel.items.compactMap { $0.command?.name }, ["b", "a-new"])
        coordinator.searchText = "a-new"
        XCTAssertEqual(coordinator.listModel.items.compactMap { $0.command?.name }, ["a-new"])
        coordinator.clearSearch()
        XCTAssertEqual(coordinator.listModel.items.compactMap { $0.command?.name }, ["b", "a-new"])
    }

    @MainActor
    func testSearchChangeAndClear_SelectsFirstCommandWithoutView() throws {
        var settings = AppSettings()
        settings.commands = [
            Command(name: "build app", command: "true", group: "开发"),
            Command(name: "build docs", command: "true", group: "开发"),
            Command(name: "clean", command: "true", group: "开发"),
        ]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        let coordinator = PaletteCoordinator(settingsManager: manager)
        coordinator.moveDown()
        XCTAssertEqual(coordinator.listModel.items[coordinator.listModel.selectedIndex].command?.name, "build docs")
        coordinator.scrollRequest = nil
        var publishedSelection: [String] = []
        let subscription = coordinator.$listModel.dropFirst().sink { model in
            if let command = model.items[model.selectedIndex].command {
                publishedSelection.append(command.name)
            }
        }
        defer { subscription.cancel() }

        coordinator.searchText = "build"

        XCTAssertEqual(coordinator.listModel.items.compactMap { $0.command?.name }, ["build app", "build docs"])
        XCTAssertEqual(coordinator.listModel.items[coordinator.listModel.selectedIndex].command?.name, "build app")
        XCTAssertEqual(coordinator.scrollRequest, 1)
        XCTAssertEqual(publishedSelection, ["build app"])

        coordinator.moveDown()
        coordinator.scrollRequest = nil
        publishedSelection.removeAll()
        coordinator.clearSearch()

        XCTAssertEqual(coordinator.listModel.items.compactMap { $0.command?.name }, ["build app", "build docs", "clean"])
        XCTAssertEqual(coordinator.listModel.items[coordinator.listModel.selectedIndex].command?.name, "build app")
        XCTAssertEqual(coordinator.scrollRequest, 1)
        XCTAssertEqual(publishedSelection, ["build app"])
    }

    @MainActor
    func testNavigationAndHover_KeepTheirScrollBehaviorWhenSearchIsUnchanged() throws {
        var settings = AppSettings()
        settings.commands = [
            Command(name: "first", command: "true"),
            Command(name: "second", command: "true"),
        ]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        let coordinator = PaletteCoordinator(settingsManager: manager)

        coordinator.moveDown()
        XCTAssertEqual(coordinator.listModel.selectedIndex, 1)
        XCTAssertEqual(coordinator.scrollRequest, 1)
        coordinator.scrollRequest = nil

        coordinator.selectOnHover(0)
        XCTAssertEqual(coordinator.listModel.selectedIndex, 0)
        XCTAssertNil(coordinator.scrollRequest)
        coordinator.selectOnHover(1)
        coordinator.searchText = ""

        XCTAssertEqual(coordinator.listModel.selectedIndex, 1)
        XCTAssertNil(coordinator.scrollRequest)
    }

    @MainActor
    func testAutoCommands_PreviousRoundCannotOverwriteCurrentResult() throws {
        let command = Command(name: "自动命令", command: "echo auto", autoExecute: true)
        var settings = AppSettings()
        settings.commands = [command]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        var completions: [@MainActor (ExecutionResult) -> Void] = []
        let coordinator = PaletteCoordinator(settingsManager: manager, runAutoCommand: { _, completion in
            completions.append(completion)
            return {}
        })

        coordinator.reset()
        coordinator.executeAutoCommands()
        let previousCompletion = try XCTUnwrap(completions.popLast())
        coordinator.reset()
        coordinator.executeAutoCommands()
        let currentCompletion = try XCTUnwrap(completions.popLast())

        XCTAssertEqual(coordinator.autoExecuteResults[command.id], .loading)
        currentCompletion(.success("new\n"))
        XCTAssertEqual(coordinator.autoExecuteResults[command.id], .success("new"))
        previousCompletion(.success("old\n"))
        XCTAssertEqual(coordinator.autoExecuteResults[command.id], .success("new"))
    }

    @MainActor
    func testAutoCommands_PreviousFailureCannotReplaceCurrentLoadingState() throws {
        let command = Command(name: "自动命令", command: "echo auto", autoExecute: true)
        var settings = AppSettings()
        settings.commands = [command]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        var completions: [@MainActor (ExecutionResult) -> Void] = []
        let coordinator = PaletteCoordinator(settingsManager: manager, runAutoCommand: { _, completion in
            completions.append(completion)
            return {}
        })

        coordinator.executeAutoCommands()
        let previousCompletion = try XCTUnwrap(completions.popLast())
        coordinator.reset()
        coordinator.executeAutoCommands()
        let currentCompletion = try XCTUnwrap(completions.popLast())

        previousCompletion(.failed(.commandTimeout(seconds: 30)))
        XCTAssertEqual(coordinator.autoExecuteResults[command.id], .loading)
        currentCompletion(.exitedAbnormally(code: 1, output: " current error\n"))
        XCTAssertEqual(coordinator.autoExecuteResults[command.id], .failure("current error"))
    }

    @MainActor
    func testReset_DiscardsPendingAutoResult() throws {
        let command = Command(name: "自动命令", command: "echo auto", autoExecute: true)
        var settings = AppSettings()
        settings.commands = [command]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        var completion: (@MainActor (ExecutionResult) -> Void)?
        let coordinator = PaletteCoordinator(settingsManager: manager, runAutoCommand: { _, callback in
            completion = callback
            return {}
        })

        coordinator.executeAutoCommands()
        let pendingCompletion = try XCTUnwrap(completion)
        XCTAssertEqual(coordinator.autoExecuteResults[command.id], .loading)
        coordinator.reset()
        pendingCompletion(.success("old"))

        XCTAssertTrue(coordinator.autoExecuteResults.isEmpty)
    }

    @MainActor
    func testAutoCommands_CurrentRoundKeepsResultsForEachAutoCommand() throws {
        let first = Command(name: "甲", command: "echo a", autoExecute: true)
        let second = Command(name: "乙", command: "exit 1", autoExecute: true)
        let manual = Command(name: "手动", command: "echo manual")
        var settings = AppSettings()
        settings.commands = [first, second, manual]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        var completions: [UUID: @MainActor (ExecutionResult) -> Void] = [:]
        let coordinator = PaletteCoordinator(settingsManager: manager, runAutoCommand: { command, completion in
            completions[command.id] = completion
            return {}
        })

        coordinator.executeAutoCommands()
        let firstCompletion = try XCTUnwrap(completions[first.id])
        let secondCompletion = try XCTUnwrap(completions[second.id])
        XCTAssertNil(completions[manual.id])
        secondCompletion(.exitedAbnormally(code: 1, output: "\n"))
        firstCompletion(.success(" a\n"))

        XCTAssertEqual(coordinator.autoExecuteResults, [first.id: .success("a"), second.id: .failure("执行失败")])
    }

    @MainActor
    func testAutoCommands_DefaultExecutorPublishesRealCommandResult() throws {
        let command = Command(
            name: "回声", command: "printf palette-default", notification: false,
            autoExecute: true, directExecution: true
        )
        var settings = AppSettings()
        settings.commands = [command]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        let coordinator = PaletteCoordinator(settingsManager: manager)
        let finished = expectation(description: "面板收到真实命令执行结果")
        let subscription = coordinator.$autoExecuteResults.sink { results in
            switch results[command.id] {
            case .success(let output):
                XCTAssertEqual(output, "palette-default")
                finished.fulfill()
            case .failure(let error):
                XCTFail(error)
                finished.fulfill()
            default:
                break
            }
        }
        defer { subscription.cancel() }

        coordinator.executeAutoCommands()

        wait(for: [finished], timeout: 10)
    }

    @MainActor
    func testResetAndNextRound_CancelPreviousAutoCommands() throws {
        let command = Command(name: "自动命令", command: "echo auto", autoExecute: true)
        var settings = AppSettings()
        settings.commands = [command]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        var cancelledRounds: [Int] = []
        var round = 0
        let coordinator = PaletteCoordinator(settingsManager: manager, runAutoCommand: { _, _ in
            round += 1
            let currentRound = round
            return { cancelledRounds.append(currentRound) }
        })

        coordinator.executeAutoCommands()
        XCTAssertEqual(cancelledRounds, [])

        coordinator.executeAutoCommands()
        XCTAssertEqual(cancelledRounds, [1], "新一轮自动执行应取消上一轮未完成进程")

        coordinator.reset()
        XCTAssertEqual(cancelledRounds, [1, 2], "reset 应取消当前轮次进程")

        coordinator.cancelAutoCommands()
        XCTAssertEqual(cancelledRounds, [1, 2], "重复取消不得再次触发已取消句柄")
    }

    @MainActor
    func testCancelAutoCommands_StopsRealRunningProcess() async throws {
        let marker = tempDirectory.appendingPathComponent("auto-must-not-run")
        let command = Command(
            name: "慢自动命令",
            command: "trap '' TERM; /bin/sleep 0.6; /usr/bin/touch \"\(marker.path)\"",
            notification: false,
            autoExecute: true,
            directExecution: true
        )
        var settings = AppSettings()
        settings.commands = [command]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        let coordinator = PaletteCoordinator(settingsManager: manager)

        coordinator.executeAutoCommands()
        try await Task.sleep(nanoseconds: 100_000_000)
        coordinator.cancelAutoCommands()
        try await Task.sleep(nanoseconds: 800_000_000)

        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path), "取消后真实自动执行子进程不能继续跑完")
    }

    @MainActor
    func testAutoCommands_SkipsHiddenCommandsHiddenGroupsAndHiddenUngrouped() throws {
        let visibleAuto = Command(name: "可见自动", command: "echo ok", autoExecute: true, group: "状态速览")
        let hiddenSelfAuto = Command(name: "自身隐藏自动", command: "echo hidden", autoExecute: true, group: "状态速览", hidden: true)
        let hiddenGroupAuto = Command(name: "隐藏分组自动", command: "echo grp", autoExecute: true, group: "运维排查")
        let hiddenUngroupedAuto = Command(name: "隐藏未分组自动", command: "echo u", autoExecute: true)
        var settings = AppSettings()
        settings.commands = [visibleAuto, hiddenSelfAuto, hiddenGroupAuto, hiddenUngroupedAuto]
        settings.hiddenGroups = ["运维排查"]
        settings.hideUngrouped = true
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)

        var executedIDs: [UUID] = []
        let coordinator = PaletteCoordinator(settingsManager: manager, runAutoCommand: { command, _ in
            executedIDs.append(command.id)
            return {}
        })

        coordinator.executeAutoCommands()

        XCTAssertEqual(executedIDs, [visibleAuto.id], "自身隐藏、所属分组隐藏或未分组隐藏的自动执行命令均不得执行")
        XCTAssertEqual(coordinator.autoExecuteResults[visibleAuto.id], .loading)
        XCTAssertNil(coordinator.autoExecuteResults[hiddenSelfAuto.id])
        XCTAssertNil(coordinator.autoExecuteResults[hiddenGroupAuto.id])
        XCTAssertNil(coordinator.autoExecuteResults[hiddenUngroupedAuto.id])
    }

    @MainActor
    func testHiddenGroupToggleInSettings_UpdatesPaletteListImmediately() throws {
        let a = Command(name: "a", command: "echo a", group: "A组")
        let b = Command(name: "b", command: "echo b", group: "B组")
        let u = Command(name: "u", command: "echo u")
        var settings = AppSettings()
        settings.commands = [a, b, u]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        let coordinator = PaletteCoordinator(settingsManager: manager)

        XCTAssertEqual(coordinator.listModel.items.compactMap { $0.command?.name }, ["a", "b", "u"])

        XCTAssertTrue(manager.saveHiddenGroups(["B组"]))
        XCTAssertEqual(coordinator.listModel.items.compactMap { $0.command?.name }, ["a", "u"])

        XCTAssertTrue(manager.setUngroupedHidden(true))
        XCTAssertEqual(coordinator.listModel.items.compactMap { $0.command?.name }, ["a"])

        XCTAssertTrue(manager.saveHiddenGroups([]))
        XCTAssertTrue(manager.setUngroupedHidden(false))
        XCTAssertEqual(coordinator.listModel.items.compactMap { $0.command?.name }, ["a", "b", "u"])
    }

    @MainActor
    func testListModelPublishesWhenSwitchingBetweenEmptyAndAllHidden() throws {
        var settings = AppSettings()
        settings.commands = []
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        let coordinator = PaletteCoordinator(settingsManager: manager)

        XCTAssertFalse(coordinator.listModel.hasAnyCommands)
        var publishedFlags: [Bool] = []
        let subscription = coordinator.$listModel.dropFirst().sink { model in
            publishedFlags.append(model.hasAnyCommands)
        }
        defer { subscription.cancel() }

        XCTAssertTrue(manager.saveCommands([Command(name: "隐藏命令", command: "true", hidden: true)]))
        XCTAssertTrue(coordinator.listModel.items.isEmpty)
        XCTAssertTrue(coordinator.listModel.hasAnyCommands)

        XCTAssertTrue(manager.saveCommands([]))
        XCTAssertTrue(coordinator.listModel.items.isEmpty)
        XCTAssertFalse(coordinator.listModel.hasAnyCommands)
        XCTAssertEqual(publishedFlags, [true, false], "空列表与全部隐藏切换时必须触发 listModel 发布")
    }

    @MainActor
    func testHidingRunningAutoCommand_CancelsInFlightProcessAndDropsLateResult() throws {
        let visibleAuto = Command(name: "保持可见", command: "echo keep", autoExecute: true, group: "状态")
        let hidingAuto = Command(name: "即将隐藏", command: "sleep 5", autoExecute: true, group: "运维")
        var settings = AppSettings()
        settings.commands = [visibleAuto, hidingAuto]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)

        var completions: [UUID: @MainActor (ExecutionResult) -> Void] = [:]
        var cancelledIDs: [UUID] = []
        let coordinator = PaletteCoordinator(settingsManager: manager, runAutoCommand: { command, completion in
            completions[command.id] = completion
            return { cancelledIDs.append(command.id) }
        })

        coordinator.executeAutoCommands()
        XCTAssertEqual(coordinator.autoExecuteResults[visibleAuto.id], .loading)
        XCTAssertEqual(coordinator.autoExecuteResults[hidingAuto.id], .loading)

        // 运行期间隐藏分组「运维」
        XCTAssertTrue(manager.saveHiddenGroups(["运维"]))

        XCTAssertEqual(cancelledIDs, [hidingAuto.id], "隐藏正在运行的自动执行命令时应立即取消其进程")
        XCTAssertNil(coordinator.autoExecuteResults[hidingAuto.id], "隐藏后应清理对应自动执行状态")
        XCTAssertEqual(coordinator.autoExecuteResults[visibleAuto.id], .loading, "其他可见自动命令不应受影响")

        // 竞态迟到回调不得写回已隐藏命令的结果，即使之后恢复可见也一样
        XCTAssertTrue(manager.saveHiddenGroups([]))
        completions[hidingAuto.id]?(.success("stale"))
        XCTAssertNil(coordinator.autoExecuteResults[hidingAuto.id], "已取消的旧任务在分组恢复可见后也不得写回过期结果")
        completions[visibleAuto.id]?(.success("ok"))
        XCTAssertEqual(coordinator.autoExecuteResults[visibleAuto.id], .success("ok"))
    }
}
