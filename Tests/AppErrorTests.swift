import XCTest
@testable import MenuBarExecutor

final class AppErrorTests: XCTestCase {

    // MARK: - AppError

    func testAppError_ConfigLoadFailed() {
        let error = AppError.configLoadFailed(NSError(domain: "test", code: 1, userInfo: nil))
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("配置加载失败"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("配置文件格式"))
    }

    func testAppError_ConfigSaveFailed() {
        let error = AppError.configSaveFailed(NSError(domain: "test", code: 2, userInfo: nil))
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("配置保存失败"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("磁盘空间"))
    }

    func testAppError_ConfigExportFailed() {
        let error = AppError.configExportFailed(NSError(domain: "test", code: 3, userInfo: nil))
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("配置导出失败"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("目标路径"))
    }

    func testAppError_CommandTimeout() {
        let error = AppError.commandTimeout(seconds: 30)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("30"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("更长时间"))
    }

    func testAppError_CommandExecutionFailed() {
        let error = AppError.commandExecutionFailed("permission denied")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("permission denied"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    // MARK: - UpdateError

    func testUpdateError_NetworkError() {
        let error = UpdateError.networkError(NSError(domain: "test", code: -1009, userInfo: nil))
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("网络连接失败"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("网络连接"))
    }

    func testUpdateError_ApiRateLimited() {
        let error = UpdateError.apiRateLimited
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("上限"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("GitHub Releases"))
    }

    func testUpdateError_NoReleaseFound() {
        let error = UpdateError.noReleaseFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("未找到"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testUpdateError_InvalidResponse() {
        let error = UpdateError.invalidResponse
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("服务器响应"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testUpdateError_VersionParseFailed() {
        let error = UpdateError.versionParseFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("版本信息解析失败"))
        XCTAssertNotNil(error.recoverySuggestion)
    }

    // MARK: - 回归：所有 case 都有 recoverySuggestion

    func testAllAppErrorCases_HaveRecoverySuggestions() {
        let cases: [AppError] = [
            .configLoadFailed(NSError(domain: "t", code: 0)),
            .configSaveFailed(NSError(domain: "t", code: 0)),
            .configExportFailed(NSError(domain: "t", code: 0)),
            .commandTimeout(seconds: 10),
            .commandExecutionFailed("test"),
        ]
        for error in cases {
            XCTAssertNotNil(error.recoverySuggestion, "\(error) 缺少 recoverySuggestion")
        }
    }

    func testAllUpdateErrorCases_HaveRecoverySuggestions() {
        let cases: [UpdateError] = [
            .networkError(NSError(domain: "t", code: 0)),
            .apiRateLimited,
            .noReleaseFound,
            .invalidResponse,
            .versionParseFailed,
        ]
        for error in cases {
            XCTAssertNotNil(error.recoverySuggestion, "\(error) 缺少 recoverySuggestion")
        }
    }
}
