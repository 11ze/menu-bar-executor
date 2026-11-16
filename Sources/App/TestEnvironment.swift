import Foundation

enum TestEnvironment {
    nonisolated static func isRunning(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
