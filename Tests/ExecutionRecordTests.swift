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
}
