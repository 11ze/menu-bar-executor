import XCTest
import AppKit
@testable import MenuBarExecutor

/// KeyDownMonitor 生命周期状态机的钉子（真实键盘拦截靠人工冒烟）
@MainActor
final class KeyDownMonitorTests: XCTestCase {

    func testStartThenStop_TogglesIsActive() {
        let monitor = KeyDownMonitor { $0 }

        XCTAssertFalse(monitor.isActive)
        monitor.start()
        XCTAssertTrue(monitor.isActive)
        monitor.stop()
        XCTAssertFalse(monitor.isActive)
    }

    func testRepeatedStartAndStop_AreIdempotent() {
        let monitor = KeyDownMonitor { $0 }

        monitor.start()
        monitor.start()
        XCTAssertTrue(monitor.isActive)

        monitor.stop()
        monitor.stop()
        XCTAssertFalse(monitor.isActive)
    }

    func testDeinitWhileActive_DoesNotCrash() {
        autoreleasepool {
            let monitor = KeyDownMonitor { $0 }
            monitor.start()
        }
        // 走到此处即证明释放路径未崩（NSEvent 无 API 断言 monitor 已移除）
        XCTAssertTrue(true)
    }
}
