import XCTest
@testable import MenuBarExecutor

final class TestEnvironmentTests: XCTestCase {

    func testIsRunning_WithXCTestConfiguration_ReturnsTrue() {
        let environment = ["XCTestConfigurationFilePath": ""]

        XCTAssertTrue(TestEnvironment.isRunning(environment: environment))
    }

    func testIsRunning_WithoutXCTestConfiguration_ReturnsFalse() {
        XCTAssertFalse(TestEnvironment.isRunning(environment: [:]))
    }

    func testIsRunning_InCurrentTestProcess_ReturnsTrue() {
        XCTAssertTrue(TestEnvironment.isRunning())
    }
}
