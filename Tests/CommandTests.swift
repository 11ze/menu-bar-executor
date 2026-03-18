import XCTest
@testable import MenuBarExecutor

final class CommandTests: XCTestCase {

    func testCommandEncoding() throws {
        let command = Command(name: "Test Command", command: "echo test")
        let data = try JSONEncoder().encode(command)
        XCTAssertFalse(data.isEmpty)
    }

    func testCommandDecoding() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "name": "Test Command",
            "command": "echo test",
            "notification": true
        }
        """.data(using: .utf8)!

        let command = try JSONDecoder().decode(Command.self, from: json)
        XCTAssertEqual(command.name, "Test Command")
        XCTAssertEqual(command.command, "echo test")
        XCTAssertTrue(command.notification)
    }

    func testCommandDecodingWithoutId() throws {
        let json = """
        {
            "name": "Legacy Command",
            "command": "ls -la",
            "notification": false
        }
        """.data(using: .utf8)!

        let command = try JSONDecoder().decode(Command.self, from: json)
        XCTAssertEqual(command.name, "Legacy Command")
        XCTAssertEqual(command.command, "ls -la")
        XCTAssertNotNil(command.id)
    }

    func testCommandWithWorkingDirectory() throws {
        let command = Command(
            name: "Test",
            command: "pwd",
            workingDirectory: "~",
            notification: true
        )

        XCTAssertEqual(command.workingDirectory, "~")
    }

    func testCommandsConfigEncoding() throws {
        let config = CommandsConfig(commands: [
            Command(name: "Cmd1", command: "echo 1"),
            Command(name: "Cmd2", command: "echo 2")
        ])

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(CommandsConfig.self, from: data)

        XCTAssertEqual(decoded.commands.count, 2)
        XCTAssertEqual(decoded.commands[0].name, "Cmd1")
        XCTAssertEqual(decoded.commands[1].name, "Cmd2")
    }
}
