import XCTest
@testable import MenuBarExecutor

/// ExecutionHistory 管理器 seam（临时目录注入）：落盘回读、100 条上限、坏 JSON 兜底
@MainActor
final class ExecutionHistoryTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("history-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDirectory)
    }

    private func makeFileURL() -> URL {
        tempDirectory.appendingPathComponent("history.json")
    }

    func testAddRecord_PersistsAcrossInstances() throws {
        let writer = ExecutionHistory(filePath: makeFileURL())
        writer.addRecord(
            ExecutionRecord(command: Command(name: "回声", command: "echo hi"), success: true, output: "hi")
        )

        let reader = ExecutionHistory(filePath: makeFileURL())
        XCTAssertEqual(reader.records.count, 1)
        XCTAssertEqual(reader.records.first?.commandName, "回声")
        XCTAssertEqual(reader.records.first?.output, "hi")
    }

    func testAddRecord_CapsAt100_NewestFirst() {
        let history = ExecutionHistory(filePath: makeFileURL())
        for i in 0..<105 {
            history.addRecord(
                ExecutionRecord(command: Command(name: "c\(i)", command: "x"), success: true, output: nil)
            )
        }

        XCTAssertEqual(history.records.count, 100)
        XCTAssertEqual(history.records.first?.commandName, "c104")
        XCTAssertEqual(history.records.last?.commandName, "c5")
    }

    func testClearHistory_PersistsAcrossInstances() throws {
        let fileURL = makeFileURL()
        let history = ExecutionHistory(filePath: fileURL)
        history.addRecord(
            ExecutionRecord(command: Command(name: "a", command: "x"), success: true, output: nil)
        )
        history.clearHistory()

        let reader = ExecutionHistory(filePath: fileURL)
        XCTAssertTrue(reader.records.isEmpty)
    }

    /// 坏 JSON：内存保持空历史，不崩溃、不清盘外的其他状态
    func testInit_BrokenJSONFallsBackToEmpty() throws {
        let fileURL = makeFileURL()
        try Data("not json at all".utf8).write(to: fileURL)

        let history = ExecutionHistory(filePath: fileURL)
        XCTAssertTrue(history.records.isEmpty)
    }
}
