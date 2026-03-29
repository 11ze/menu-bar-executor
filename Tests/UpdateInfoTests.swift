import XCTest
@testable import MenuBarExecutor

final class UpdateInfoTests: XCTestCase {

    // MARK: - parseVersion

    func testParseVersion_StandardVersion() {
        let result = UpdateInfo.parseVersion("1.2.3")
        XCTAssertEqual(result.major, 1)
        XCTAssertEqual(result.minor, 2)
        XCTAssertEqual(result.patch, 3)
    }

    func testParseVersion_WithVPrefix() {
        let result = UpdateInfo.parseVersion("v2.0.0")
        XCTAssertEqual(result.major, 2)
        XCTAssertEqual(result.minor, 0)
        XCTAssertEqual(result.patch, 0)
    }

    func testParseVersion_MajorOnly() {
        let result = UpdateInfo.parseVersion("3")
        XCTAssertEqual(result.major, 3)
        XCTAssertEqual(result.minor, 0)
        XCTAssertEqual(result.patch, 0)
    }

    func testParseVersion_MajorMinor() {
        let result = UpdateInfo.parseVersion("1.5")
        XCTAssertEqual(result.major, 1)
        XCTAssertEqual(result.minor, 5)
        XCTAssertEqual(result.patch, 0)
    }

    func testParseVersion_ManyComponents() {
        let result = UpdateInfo.parseVersion("1.2.3.4.5")
        XCTAssertEqual(result.major, 1)
        XCTAssertEqual(result.minor, 2)
        XCTAssertEqual(result.patch, 3)
    }

    func testParseVersion_EmptyString() {
        let result = UpdateInfo.parseVersion("")
        XCTAssertEqual(result.major, 0)
        XCTAssertEqual(result.minor, 0)
        XCTAssertEqual(result.patch, 0)
    }

    func testParseVersion_InvalidSegments() {
        let result = UpdateInfo.parseVersion("1.beta.3")
        XCTAssertEqual(result.major, 1)
        XCTAssertEqual(result.minor, 0)
        XCTAssertEqual(result.patch, 3)
    }

    func testParseVersion_LargeNumbers() {
        let result = UpdateInfo.parseVersion("100.200.300")
        XCTAssertEqual(result.major, 100)
        XCTAssertEqual(result.minor, 200)
        XCTAssertEqual(result.patch, 300)
    }

    // MARK: - compareVersions

    func testCompareVersions_Equal() {
        let result = UpdateInfo.compareVersions("1.2.3", "1.2.3")
        XCTAssertEqual(result, .orderedSame)
    }

    func testCompareVersions_FirstMajorHigher() {
        let result = UpdateInfo.compareVersions("2.0.0", "1.9.9")
        XCTAssertEqual(result, .orderedDescending)
    }

    func testCompareVersions_SecondMajorHigher() {
        let result = UpdateInfo.compareVersions("1.9.9", "2.0.0")
        XCTAssertEqual(result, .orderedAscending)
    }

    func testCompareVersions_MajorEqual_MinorDiffers() {
        let result = UpdateInfo.compareVersions("1.3.0", "1.2.9")
        XCTAssertEqual(result, .orderedDescending)
    }

    func testCompareVersions_PatchDiffers() {
        let result = UpdateInfo.compareVersions("1.2.3", "1.2.4")
        XCTAssertEqual(result, .orderedAscending)
    }

    func testCompareVersions_WithVPrefix() {
        let result = UpdateInfo.compareVersions("v1.2.0", "v1.2.1")
        XCTAssertEqual(result, .orderedAscending)
    }

    func testCompareVersions_MixedPrefix() {
        let result = UpdateInfo.compareVersions("1.2.0", "v1.2.1")
        XCTAssertEqual(result, .orderedAscending)
    }

    func testCompareVersions_BothZero() {
        let result = UpdateInfo.compareVersions("0.0.0", "0.0.0")
        XCTAssertEqual(result, .orderedSame)
    }

    // MARK: - hasUpdate

    func testHasUpdate_LatestHigher() {
        let info = UpdateInfo(
            currentVersion: "1.0.0",
            latestVersion: "2.0.0",
            releaseURL: URL(string: "https://example.com")!,
            releaseNotes: nil
        )
        XCTAssertTrue(info.hasUpdate)
    }

    func testHasUpdate_SameVersion() {
        let info = UpdateInfo(
            currentVersion: "1.0.0",
            latestVersion: "1.0.0",
            releaseURL: URL(string: "https://example.com")!,
            releaseNotes: nil
        )
        XCTAssertFalse(info.hasUpdate)
    }

    func testHasUpdate_CurrentHigher() {
        let info = UpdateInfo(
            currentVersion: "2.0.0",
            latestVersion: "1.0.0",
            releaseURL: URL(string: "https://example.com")!,
            releaseNotes: nil
        )
        XCTAssertFalse(info.hasUpdate)
    }
}
