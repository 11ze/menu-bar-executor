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

    func testAppSettingsEncoding() throws {
        var settings = AppSettings()
        settings.commands = [
            Command(name: "Cmd1", command: "echo 1"),
            Command(name: "Cmd2", command: "echo 2")
        ]

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.commands.count, 2)
        XCTAssertEqual(decoded.commands[0].name, "Cmd1")
        XCTAssertEqual(decoded.commands[1].name, "Cmd2")
    }

    // MARK: - Equatable

    func testEquatable_SameValues() {
        let uuid = UUID()
        let a = Command(id: uuid, name: "Test", command: "echo", notification: true)
        let b = Command(id: uuid, name: "Test", command: "echo", notification: true)
        XCTAssertEqual(a, b)
    }

    func testEquatable_DifferentNames() {
        let uuid = UUID()
        let a = Command(id: uuid, name: "A", command: "echo", notification: true)
        let b = Command(id: uuid, name: "B", command: "echo", notification: true)
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_DifferentUUIDs() {
        let a = Command(id: UUID(), name: "Test", command: "echo", notification: true)
        let b = Command(id: UUID(), name: "Test", command: "echo", notification: true)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - 默认值

    func testDefaultNotification_IsTrue() {
        let command = Command(name: "Test", command: "echo")
        XCTAssertTrue(command.notification)
    }

    // MARK: - 解码边界

    func testDecoding_MalformedUUID() throws {
        let json = """
        {
            "id": "not-a-uuid",
            "name": "Test",
            "command": "echo",
            "notification": true
        }
        """.data(using: .utf8)!

        let command = try JSONDecoder().decode(Command.self, from: json)
        // 无效 UUID 应触发 try? 回退，生成新 UUID
        XCTAssertNotEqual(command.id.uuidString, "not-a-uuid")
    }

    func testDecoding_NonStringUUID() throws {
        let json = """
        {
            "id": 12345,
            "name": "Test",
            "command": "echo",
            "notification": true
        }
        """.data(using: .utf8)!

        let command = try JSONDecoder().decode(Command.self, from: json)
        XCTAssertNotNil(command.id)
    }

    func testDecoding_MissingNotification() throws {
        let json = """
        {
            "name": "Test",
            "command": "echo"
        }
        """.data(using: .utf8)!

        let command = try JSONDecoder().decode(Command.self, from: json)
        XCTAssertTrue(command.notification)
    }

    func testDecoding_ExplicitFalseNotification() throws {
        let json = """
        {
            "name": "Test",
            "command": "echo",
            "notification": false
        }
        """.data(using: .utf8)!

        let command = try JSONDecoder().decode(Command.self, from: json)
        XCTAssertFalse(command.notification)
    }

    func testDecoding_WithWorkingDirectory() throws {
        let json = """
        {
            "name": "Test",
            "command": "pwd",
            "workingDirectory": "/tmp"
        }
        """.data(using: .utf8)!

        let command = try JSONDecoder().decode(Command.self, from: json)
        XCTAssertEqual(command.workingDirectory, "/tmp")
    }

    func testDecoding_WithoutWorkingDirectory() throws {
        let json = """
        {
            "name": "Test",
            "command": "pwd"
        }
        """.data(using: .utf8)!

        let command = try JSONDecoder().decode(Command.self, from: json)
        XCTAssertNil(command.workingDirectory)
    }

    func testEncoding_WithWorkingDirectory() throws {
        let command = Command(name: "Test", command: "pwd", workingDirectory: "/home/user")
        let data = try JSONEncoder().encode(command)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("workingDirectory"))
    }

    func testEncoding_AllFieldsRoundTrip() throws {
        let command = Command(
            name: "Full",
            command: "ls -la",
            workingDirectory: "/tmp",
            notification: false
        )
        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(Command.self, from: data)
        XCTAssertEqual(decoded.name, "Full")
        XCTAssertEqual(decoded.command, "ls -la")
        XCTAssertEqual(decoded.workingDirectory, "/tmp")
        XCTAssertFalse(decoded.notification)
    }
}
