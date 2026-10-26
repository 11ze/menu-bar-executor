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
    func testAutoCommands_PreviousRoundCannotOverwriteCurrentResult() throws {
        let command = Command(name: "自动命令", command: "echo auto", autoExecute: true)
        var settings = AppSettings()
        settings.commands = [command]
        let fileURL = try writeSettings(settings, named: "settings.json")
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        var completions: [@MainActor (ExecutionResult) -> Void] = []
        let coordinator = PaletteCoordinator(settingsManager: manager, runAutoCommand: { _, completion in
            completions.append(completion)
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
}
