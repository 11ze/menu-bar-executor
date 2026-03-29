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
}
