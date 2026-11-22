import XCTest
@testable import MenuBarExecutor

final class NotificationManagerTests: XCTestCase {

    @MainActor
    func testInitialization_TestPolicy_DoesNotRequestAuthorization() {
        var authorizationRequestCount = 0
        let policy = NotificationPolicy(
            environment: ["XCTestConfigurationFilePath": ""]
        )

        _ = NotificationManager(
            policy: policy,
            requestAuthorizationAction: { authorizationRequestCount += 1 }
        )

        XCTAssertEqual(authorizationRequestCount, 0)
    }

    func testFailureBody_IncludesExitCodeAndOutputWithoutDuplication() {
        XCTAssertEqual(
            NotificationManager.failureBody(error: "退出码 1", output: " err-side\n"),
            "错误: 退出码 1\n输出: err-side"
        )
        XCTAssertEqual(
            NotificationManager.failureBody(error: "退出码 2", output: "  \n"),
            "错误: 退出码 2"
        )
        XCTAssertEqual(
            NotificationManager.failureBody(error: "permission denied", output: "permission denied\n"),
            "错误: permission denied"
        )
    }
}
