import XCTest
import CoreGraphics
@testable import MenuBarExecutor

final class AppSettingsManagerTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("appsettings-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDirectory)
    }

    private func makeFileURL() -> URL {
        tempDirectory.appendingPathComponent("settings.json")
    }

    // MARK: - 迁移纯函数

    func testMigrateIfNeeded_FakeGroupSeparator() {
        var settings = AppSettings()
        settings.commands = [
            Command(name: "分组甲", command: "echo ----------------", notification: false),
            Command(name: "ls", command: "ls"),
            Command(name: "分组乙", command: "echo ===", notification: false),
            Command(name: "pwd", command: "pwd"),
        ]

        let migrated = AppSettings.migrateIfNeeded(&settings)

        XCTAssertTrue(migrated)
        XCTAssertEqual(settings.commands.map(\.name), ["ls", "pwd"])
        XCTAssertEqual(settings.commands[0].group, "分组甲")
        XCTAssertEqual(settings.commands[1].group, "分组乙")
        XCTAssertEqual(settings.groupOrder, ["分组甲", "分组乙"])
    }

    func testMigrateIfNeeded_DuplicateCommandIds() {
        var settings = AppSettings()
        let original = Command(name: "A", command: "ls")
        let duplicate = Command(name: "B", command: "pwd")
        settings.commands = [original, duplicate]
        settings.commands[1].id = original.id

        let migrated = AppSettings.migrateIfNeeded(&settings)

        XCTAssertTrue(migrated)
        XCTAssertEqual(settings.commands[0].id, original.id)
        XCTAssertNotEqual(settings.commands[0].id, settings.commands[1].id)
    }

    func testMigrateIfNeeded_CleanSettingsReturnsFalse() {
        var settings = AppSettings()
        settings.commands = [
            Command(name: "ls", command: "ls"),
            Command(name: "pwd", command: "pwd"),
        ]
        let snapshot = settings

        let migrated = AppSettings.migrateIfNeeded(&settings)

        XCTAssertFalse(migrated)
        XCTAssertEqual(settings, snapshot)
    }

    // MARK: - Manager seam（临时目录注入）

    /// 坏 JSON：加载失败时内存保持默认，且未加载成功前拒绝写入，磁盘内容不被空默认值覆盖
    @MainActor
    func testInit_BrokenJSONDoesNotOverwriteDisk() throws {
        let fileURL = makeFileURL()
        let broken = Data("not json at all".utf8)
        try broken.write(to: fileURL)

        // notifyLoadError 关闭：测试环境不向系统通知中心泄漏配置错误弹窗
        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false, notifyLoadError: false)
        XCTAssertTrue(manager.settings.commands.isEmpty)

        manager.setDefaultInputSource("com.apple.keylayout.ABC")
        XCTAssertEqual(try Data(contentsOf: fileURL), broken)
    }

    /// 写入落盘可被新实例读到
    @MainActor
    func testSaveLoad_RoundTripAcrossInstances() throws {
        let fileURL = makeFileURL()

        let writer = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        writer.setDefaultInputSource("com.apple.keylayout.ABC")

        let reader = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        XCTAssertEqual(reader.settings.defaultInputSourceID, "com.apple.keylayout.ABC")
    }

    /// 原子写入不残留 .tmp 文件
    @MainActor
    func testSave_LeavesNoTempFile() throws {
        let fileURL = makeFileURL()

        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        manager.setSkippedVersion("1.2.3")

        let contents = try FileManager.default.contentsOfDirectory(atPath: tempDirectory.path)
        XCTAssertEqual(contents, ["settings.json"])
    }

    // MARK: - 文件监听

    /// 外部就地写文件，等待防抖后配置被重载
    @MainActor
    func testExternalWrite_TriggersReload() async throws {
        let fileURL = makeFileURL()
        try Data(#"{"commands": []}"#.utf8).write(to: fileURL)

        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: true)

        let external = Data(#"{"commands": [], "defaultInputSourceID": "com.apple.external"}"#.utf8)
        try external.write(to: fileURL)

        try await waitUntil(timeout: 3) {
            manager.settings.defaultInputSourceID == "com.apple.external"
        }
    }

    /// bug① 复现：save 失败（目录只读）后 skip 标志不得残留，下一次真实的外部修改仍要触发重载
    @MainActor
    func testSaveFailure_DoesNotSwallowNextExternalChange() async throws {
        let fileURL = makeFileURL()
        try Data(#"{"commands": []}"#.utf8).write(to: fileURL)

        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: true)

        // 目录只读 → save 失败
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: tempDirectory.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempDirectory.path)
        }
        manager.setDefaultInputSource("com.apple.keylayout.ABC")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempDirectory.path)

        // 外部就地写（同 inode，触发 .write）
        let external = Data(#"{"commands": [], "defaultInputSourceID": "com.apple.external"}"#.utf8)
        try external.write(to: fileURL)

        try await waitUntil(timeout: 3) {
            manager.settings.defaultInputSourceID == "com.apple.external"
        }
    }

    /// 迁移场景（init 时旧格式触发写盘 + 监听重建）后，外部写仍能触发重载
    @MainActor
    func testMigrationThenExternalWrite_TriggersReload() async throws {
        let fileURL = makeFileURL()
        // 旧格式：echo 分隔符假分组
        let legacy = """
        {"commands": [
            {"name": "分组甲", "command": "echo ----------------", "notification": false},
            {"name": "ls", "command": "ls"}
        ]}
        """
        try Data(legacy.utf8).write(to: fileURL)

        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: true)
        XCTAssertEqual(manager.settings.commands.first?.group, "分组甲")

        let external = Data(#"{"commands": [], "skippedVersion": "9.9.9"}"#.utf8)
        try external.write(to: fileURL)

        try await waitUntil(timeout: 3) {
            manager.settings.skippedVersion == "9.9.9"
        }
    }

    /// 自身 save 后紧跟外部写：save 不得干扰下一次外部修改触发的重载
    /// （原「自身 save 不触发重载通知」的观察面随 settingsDidReload 通知删除，
    ///   回环语义由本测试覆盖：若 save 误触发重载，外部写的时序窗口会被扰动）
    @MainActor
    func testOwnSaveThenExternalWrite_ExternalWins() async throws {
        let fileURL = makeFileURL()
        try Data(#"{"commands": []}"#.utf8).write(to: fileURL)

        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: true)

        manager.setSkippedVersion("1.0.0")

        let external = Data(#"{"commands": [], "skippedVersion": "2.0.0"}"#.utf8)
        try external.write(to: fileURL)

        try await waitUntil(timeout: 3) {
            manager.settings.skippedVersion == "2.0.0"
        }
    }

    /// 写帧前必须从磁盘重载：内存落后于磁盘时写帧，磁盘上外部修改的字段不丢
    @MainActor
    func testUpdatePaletteFrame_KeepsExternalChangesOnDisk() throws {
        let fileURL = makeFileURL()
        try Data(#"{"commands": []}"#.utf8).write(to: fileURL)

        let manager = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)

        // 外部改磁盘（监听关闭，内存保持落后）
        try Data(#"{"commands": [], "skippedVersion": "5.0.0"}"#.utf8).write(to: fileURL)

        manager.updatePaletteFrame(origin: CGPoint(x: 10, y: 20), size: NSSize(width: 300, height: 500))

        let reader = AppSettingsManager(filePath: fileURL, enableFileMonitoring: false)
        XCTAssertEqual(reader.settings.palettePosition, CGPoint(x: 10, y: 20))
        XCTAssertEqual(reader.settings.paletteSize, NSSize(width: 300, height: 500))
        XCTAssertEqual(reader.settings.skippedVersion, "5.0.0")
    }

    // MARK: - 轮询等待

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("等待条件超时（\(timeout)s）")
    }
}
