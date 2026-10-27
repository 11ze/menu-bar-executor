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

    func testMarkedTextKeepsConfirmationAndNavigationOutOfCommandHandler() throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let input = NSTextView(frame: window.contentLayoutRect)
        window.contentView = input
        XCTAssertTrue(window.makeFirstResponder(input))
        input.setMarkedText("pinyin", selectedRange: NSRange(location: 6, length: 0),
                            replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(input.hasMarkedText())
        var handled = 0
        let monitor = KeyDownMonitor { _ in handled += 1; return nil }
        for keyCode: UInt16 in [36, 48, 53, 125, 126] {
            let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
                modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode))
            XCTAssertTrue(event.window === window)
            XCTAssertTrue(monitor.handle(event) === event, "组词期间不得拦截候选确认或导航")
        }
        XCTAssertEqual(handled, 0)
        input.unmarkText()
        let enter = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36))
        XCTAssertNil(monitor.handle(enter))
        XCTAssertEqual(handled, 1, "结束组词后，新的回车仍应交给命令处理器")
    }

    func testDeinitWhileActive_DoesNotCrash() {
        autoreleasepool {
            let monitor = KeyDownMonitor { $0 }
            monitor.start()
        }
        // 此用例以释放路径不崩溃为验收，NSEvent 没有查询监听器是否已移除的 API。
    }
}
