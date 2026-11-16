import XCTest
@testable import MenuBarExecutor

final class NotificationPolicyTests: XCTestCase {

    func testTestEnvironment_DisablesAuthorizationAndAlerts() {
        let policy = NotificationPolicy(
            environment: ["XCTestConfigurationFilePath": ""]
        )

        XCTAssertFalse(policy.requestsAuthorizationOnLaunch)
        XCTAssertFalse(policy.showsAlerts)
    }

    func testProductionEnvironment_EnablesAuthorizationAndAlerts() {
        let policy = NotificationPolicy(environment: [:])

        XCTAssertTrue(policy.requestsAuthorizationOnLaunch)
        XCTAssertTrue(policy.showsAlerts)
    }
}
