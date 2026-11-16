import Foundation

struct NotificationPolicy {
    let requestsAuthorizationOnLaunch: Bool
    let showsAlerts: Bool

    init(environment: [String: String]) {
        let isRunningTests = TestEnvironment.isRunning(environment: environment)
        requestsAuthorizationOnLaunch = !isRunningTests
        showsAlerts = !isRunningTests
    }
}
