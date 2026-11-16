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
}
