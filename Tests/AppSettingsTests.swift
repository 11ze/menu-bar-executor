import XCTest
@testable import MenuBarExecutor

final class AppSettingsTests: XCTestCase {

    // MARK: - 默认初始化

    func testDefaultInit() {
        let settings = AppSettings()
        XCTAssertTrue(settings.commands.isEmpty)
        XCTAssertNil(settings.palettePosition)
        XCTAssertNil(settings.paletteSize)
        XCTAssertNil(settings.defaultInputSourceID)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertNil(settings.lastUpdateCheckDate)
        XCTAssertNil(settings.skippedVersion)
    }

    // MARK: - 编解码往返

    func testEncodeDecode_RoundTrip() throws {
        var settings = AppSettings()
        settings.commands = [
            Command(name: "Build", command: "xcodebuild", workingDirectory: "/tmp"),
            Command(name: "Clean", command: "rm -rf build"),
        ]
        settings.palettePosition = CGPoint(x: 100, y: 200)
        settings.paletteSize = NSSize(width: 400, height: 600)
        settings.defaultInputSourceID = "com.apple.keylayout.ABC"
        settings.launchAtLogin = true
        settings.lastUpdateCheckDate = Date(timeIntervalSince1970: 1_700_000_000)
        settings.skippedVersion = "2.0.0"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(settings)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.commands.count, 2)
        XCTAssertEqual(decoded.commands[0].name, "Build")
        XCTAssertEqual(decoded.commands[0].workingDirectory, "/tmp")
        XCTAssertEqual(decoded.commands[1].name, "Clean")
        XCTAssertEqual(decoded.palettePosition, CGPoint(x: 100, y: 200))
        XCTAssertEqual(decoded.paletteSize, NSSize(width: 400, height: 600))
        XCTAssertEqual(decoded.defaultInputSourceID, "com.apple.keylayout.ABC")
        XCTAssertTrue(decoded.launchAtLogin)
        XCTAssertEqual(decoded.skippedVersion, "2.0.0")
    }

    // MARK: - CGPoint 解码

    func testDecode_CGPoint() throws {
        let json = """
        {
            "palettePosition": {"x": 100.5, "y": 200.0}
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(settings.palettePosition, CGPoint(x: 100.5, y: 200.0))
    }

    // MARK: - NSSize 解码

    func testDecode_NSSize() throws {
        let json = """
        {
            "paletteSize": {"width": 400.0, "height": 600.0}
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(settings.paletteSize, NSSize(width: 400, height: 600))
    }

    // MARK: - 缺失可选字段

    func testDecode_MissingOptionals() throws {
        let json = """
        {"commands": []}
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertNil(settings.palettePosition)
        XCTAssertNil(settings.paletteSize)
        XCTAssertNil(settings.defaultInputSourceID)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertNil(settings.lastUpdateCheckDate)
        XCTAssertNil(settings.skippedVersion)
    }

    func testDecode_MissingCommands() throws {
        let json = """
        {}
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertTrue(settings.commands.isEmpty)
    }

    // MARK: - ISO8601 日期解码

    func testDecode_LastUpdateCheckDate() throws {
        let json = """
        {
            "lastUpdateCheckDate": "2025-01-15T10:30:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let settings = try decoder.decode(AppSettings.self, from: json)
        XCTAssertNotNil(settings.lastUpdateCheckDate)
    }

    // MARK: - 跳过版本

    func testDecode_SkippedVersion() throws {
        let json = """
        {
            "skippedVersion": "v2.0.0"
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(settings.skippedVersion, "v2.0.0")
    }

    // MARK: - 编码验证

    func testEncode_CGPoint_OutputsObject() throws {
        var settings = AppSettings()
        settings.palettePosition = CGPoint(x: 50, y: 75)

        let data = try JSONEncoder().encode(settings)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("palettePosition"))
        XCTAssertTrue(json.contains("\"x\""))
        XCTAssertTrue(json.contains("\"y\""))
    }

    func testEncode_NilPosition_OmitsKey() throws {
        let settings = AppSettings()

        let data = try JSONEncoder().encode(settings)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertFalse(json.contains("palettePosition"))
    }

    // MARK: - 旧格式兼容

    func testDecode_LegacyFormat() throws {
        let json = """
        {
            "commands": [{"name": "Old", "command": "ls"}],
            "launchAtLogin": false
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(settings.commands.count, 1)
        XCTAssertEqual(settings.commands[0].name, "Old")
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertNil(settings.lastUpdateCheckDate)
        XCTAssertNil(settings.skippedVersion)
    }

    // MARK: - 浮点坐标精确往返

    func testEncodeDecode_FloatCoordinates() throws {
        var settings = AppSettings()
        settings.palettePosition = CGPoint(x: 123.456, y: 789.012)
        settings.paletteSize = NSSize(width: 111.222, height: 333.444)

        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.palettePosition?.x, 123.456)
        XCTAssertEqual(decoded.palettePosition?.y, 789.012)
        XCTAssertEqual(decoded.paletteSize?.width, 111.222)
        XCTAssertEqual(decoded.paletteSize?.height, 333.444)
    }
}
