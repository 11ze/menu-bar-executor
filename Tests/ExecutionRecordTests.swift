import XCTest
@testable import MenuBarExecutor

final class ExecutionRecordTests: XCTestCase {

    func testExecutionRecordCreation() {
        let command = Command(name: "Test", command: "echo test")
        let record = ExecutionRecord(command: command, success: true, output: "test output")

        XCTAssertEqual(record.commandName, "Test")
        XCTAssertEqual(record.commandText, "echo test")
        XCTAssertTrue(record.success)
        XCTAssertEqual(record.output, "test output")
    }

    func testExecutionRecordOutputTruncation() {
        let longOutput = String(repeating: "a", count: 600)
        let command = Command(name: "Test", command: "echo test")
        let record = ExecutionRecord(command: command, success: true, output: longOutput)

        XCTAssertNotNil(record.output)
        XCTAssertLessThanOrEqual(record.output!.count, 503)  // 500 + "..."
        XCTAssertTrue(record.output!.hasSuffix("..."))
    }

    func testExecutionRecordEncoding() throws {
        let command = Command(name: "Test", command: "echo test")
        let record = ExecutionRecord(command: command, success: true, output: "output")

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(ExecutionRecord.self, from: data)

        XCTAssertEqual(decoded.commandName, record.commandName)
        XCTAssertEqual(decoded.success, record.success)
        XCTAssertEqual(decoded.output, record.output)
    }

    // MARK: - 截断边界

    func testOutputTruncation_ExactLimit() {
        let output = String(repeating: "a", count: 500)
        let command = Command(name: "Test", command: "echo")
        let record = ExecutionRecord(command: command, success: true, output: output)
        XCTAssertEqual(record.output, output)
        XCTAssertFalse(record.output!.hasSuffix("..."))
    }

    func testOutputTruncation_JustOver() {
        let output = String(repeating: "a", count: 501)
        let command = Command(name: "Test", command: "echo")
        let record = ExecutionRecord(command: command, success: true, output: output)
        XCTAssertNotNil(record.output)
        XCTAssertTrue(record.output!.hasSuffix("..."))
        XCTAssertEqual(record.output!.count, 503) // 500 + "..."
    }

    // MARK: - nil 与空字符串

    func testOutput_Nil() {
        let command = Command(name: "Test", command: "echo")
        let record = ExecutionRecord(command: command, success: true, output: nil)
        XCTAssertNil(record.output)
    }

    func testOutput_EmptyString() {
        let command = Command(name: "Test", command: "echo")
        let record = ExecutionRecord(command: command, success: true, output: "")
        XCTAssertEqual(record.output, "")
    }

    // MARK: - 唯一性

    func testIdentifiable_UniqueIdPerCreation() {
        let command = Command(name: "Test", command: "echo")
        let a = ExecutionRecord(command: command, success: true, output: nil)
        let b = ExecutionRecord(command: command, success: true, output: nil)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testEncoding_Decoding_FullRoundTrip() throws {
        let command = Command(name: "Build", command: "xcodebuild build", workingDirectory: "/tmp")
        let record = ExecutionRecord(command: command, success: false, output: "error: build failed")

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(ExecutionRecord.self, from: data)

        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.commandName, "Build")
        XCTAssertEqual(decoded.commandText, "xcodebuild build")
        XCTAssertFalse(decoded.success)
        XCTAssertEqual(decoded.output, "error: build failed")
    }

    // MARK: - 紧凑中文时间格式

    func testFormatExecutedAtUsesCompactChineseFormats() throws {
        var calendar = Calendar(identifier: .gregorian)
        let tz = try XCTUnwrap(TimeZone(secondsFromGMT: 8 * 3600))
        calendar.timeZone = tz
        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ s: Int) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s)))
        }

        let now = try date(2026, 11, 26, 20, 50, 0)
        XCTAssertEqual(
            ExecutionRecord.formatExecutedAt(try date(2026, 11, 26, 10, 42, 8), relativeTo: now, calendar: calendar, timeZone: tz),
            "今天 10:42:08"
        )
        XCTAssertEqual(
            ExecutionRecord.formatExecutedAt(try date(2026, 11, 25, 18, 6, 34), relativeTo: now, calendar: calendar, timeZone: tz),
            "昨天 18:06:34"
        )
        XCTAssertEqual(
            ExecutionRecord.formatExecutedAt(try date(2026, 11, 20, 9, 5, 0), relativeTo: now, calendar: calendar, timeZone: tz),
            "11月20日 09:05"
        )
        XCTAssertEqual(
            ExecutionRecord.formatExecutedAt(try date(2025, 12, 31, 23, 59, 0), relativeTo: now, calendar: calendar, timeZone: tz),
            "2025年12月31日 23:59"
        )
    }

    func testResolveCommandPrefersMatchingConfiguredCommandAndFallsBackToRecord() {
        let configured = Command(
            name: "构建项目",
            command: "swift build",
            workingDirectory: "~/Projects/demo",
            notification: false,
            autoExecute: false,
            group: "开发工具",
            directExecution: true
        )
        let record = ExecutionRecord(command: configured, success: true, output: "ok")

        let matched = ExecutionHistory.resolveCommand(for: record, in: [configured])
        XCTAssertEqual(matched.id, configured.id)
        XCTAssertEqual(matched.workingDirectory, "~/Projects/demo")
        XCTAssertTrue(matched.directExecution)
        XCTAssertFalse(matched.notification)

        let modified = Command(name: "构建项目", command: "swift test", workingDirectory: "~/other")
        let fallback = ExecutionHistory.resolveCommand(for: record, in: [modified])
        XCTAssertEqual(fallback.name, "构建项目")
        XCTAssertEqual(fallback.command, "swift build")
        XCTAssertNil(fallback.workingDirectory)
    }

    func testFiltersEnsuringVisibilityClearsOnlyBlockingFilters() {
        let successRecord = ExecutionRecord(command: Command(name: "启动 Docker 服务", command: "open -a Docker"), success: true, output: "ok")
        let failedRecord = ExecutionRecord(command: Command(name: "刷新 DNS 缓存", command: "sudo flush"), success: false, output: "err")

        // 勾选「仅失败」时重跑成功，应关闭「仅失败」以确保新记录可见，同时保留仍匹配的搜索词
        let rerunSuccess = ExecutionHistory.filtersEnsuringVisibility(of: successRecord, searchText: "qd", onlyFailed: true)
        XCTAssertEqual(rerunSuccess.searchText, "qd")
        XCTAssertFalse(rerunSuccess.onlyFailed)

        // 搜索词不匹配目标记录时应清空搜索词，但若目标为失败记录则可保留「仅失败」
        let mismatchSearch = ExecutionHistory.filtersEnsuringVisibility(of: failedRecord, searchText: "Docker", onlyFailed: true)
        XCTAssertEqual(mismatchSearch.searchText, "")
        XCTAssertTrue(mismatchSearch.onlyFailed)
    }
}
