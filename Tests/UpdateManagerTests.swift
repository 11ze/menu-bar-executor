import XCTest
@testable import MenuBarExecutor

@MainActor
final class UpdateManagerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("update-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testManualCheckIncludesSkippedVersion() async {
        let settings = AppSettingsManager(filePath: directory.appendingPathComponent("settings.json"), enableFileMonitoring: false)
        settings.setSkippedVersion("2.0.0")
        let manager = UpdateManager(settingsManager: settings, currentVersion: "1.0.0", fetchRelease: {
            GitHubRelease(tagName: "v2.0.0", htmlURL: UpdateConfig.releasePageURL, body: nil)
        })
        let result = await manager.checkForUpdate(force: true)
        guard case .available(let info) = result else { return XCTFail("手动检查应返回已跳过的新版本") }
        XCTAssertEqual(info.latestVersion, "2.0.0")
    }
    func testAutomaticCheckSkipsVersionButManualCheckSharesItsRequest() async {
        let settings = AppSettingsManager(filePath: directory.appendingPathComponent("settings.json"), enableFileMonitoring: false)
        settings.setSkippedVersion("2.0.0")
        var requests = 0
        let manager = UpdateManager(settingsManager: settings, currentVersion: "1.0.0", fetchRelease: {
            requests += 1
            try await Task.sleep(nanoseconds: 50_000_000)
            return GitHubRelease(tagName: "v2.0.0", htmlURL: UpdateConfig.releasePageURL, body: nil)
        })
        async let automatic = manager.checkForUpdate()
        async let manual = manager.checkForUpdate(force: true)
        let (autoResult, manualResult) = await (automatic, manual)
        guard case .skipped = autoResult else { return XCTFail("自动检查应尊重跳过版本") }
        guard case .available(let info) = manualResult else { return XCTFail("手动检查应显示新版") }
        XCTAssertEqual(info.latestVersion, "2.0.0")
        XCTAssertEqual(requests, 1)
        XCTAssertFalse(manager.isChecking)
    }

    func testFailedRequestIsSharedAndNextManualCheckCanRetry() async {
        let settings = AppSettingsManager(filePath: directory.appendingPathComponent("settings.json"), enableFileMonitoring: false)
        var requests = 0
        let manager = UpdateManager(settingsManager: settings, currentVersion: "1.0.0", fetchRelease: {
            requests += 1
            try await Task.sleep(nanoseconds: 50_000_000)
            if requests == 1 { throw UpdateError.apiRateLimited }
            return GitHubRelease(tagName: "v1.0.0", htmlURL: UpdateConfig.releasePageURL, body: nil)
        })
        async let automatic = manager.checkForUpdate()
        async let manual = manager.checkForUpdate(force: true)
        let results = await [automatic, manual]
        for result in results {
            guard case .failed(.apiRateLimited) = result else { return XCTFail("调用方应拿到同一请求的失败") }
        }
        XCTAssertEqual(requests, 1)
        XCTAssertNil(settings.settings.lastUpdateCheckDate)
        let retry = await manager.checkForUpdate(force: true)
        guard case .upToDate = retry else { return XCTFail("重试成功后应报告无更新") }
        XCTAssertEqual(requests, 2)
        XCTAssertNotNil(settings.settings.lastUpdateCheckDate)
    }

    func testAutomaticCheckWithinIntervalDoesNotRequestAndManualCheckStillRequests() async {
        let settings = AppSettingsManager(filePath: directory.appendingPathComponent("settings.json"), enableFileMonitoring: false)
        settings.touchUpdateCheckDate()
        var requests = 0
        let manager = UpdateManager(settingsManager: settings, currentVersion: "1.0.0", fetchRelease: {
            requests += 1
            return GitHubRelease(tagName: "v1.0.0", htmlURL: UpdateConfig.releasePageURL, body: nil)
        })
        let automatic = await manager.checkForUpdate()
        guard case .skipped = automatic else { return XCTFail("间隔内的自动检查应跳过") }
        XCTAssertEqual(requests, 0)
        let manual = await manager.checkForUpdate(force: true)
        guard case .upToDate = manual else { return XCTFail("手动检查应请求并报告无更新") }
        XCTAssertEqual(requests, 1)
    }

}
