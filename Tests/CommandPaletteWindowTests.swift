import AppKit
import XCTest
@testable import MenuBarExecutor

final class CommandPaletteWindowTests: XCTestCase {
    @MainActor
    func testPaletteAllowsChangingHeight() async throws {
        let controller = CommandPaletteWindowController.shared
        // 等初次布局执行，检查真正应用到原生窗口的约束。
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        let window = try XCTUnwrap(controller.window)
        XCTAssertGreaterThan(window.maxSize.height, window.minSize.height,
                             "用户必须能够拖动面板改变高度")
        let frame = window.frame
        let coordinator = PaletteCoordinator.shared
        let searchText = coordinator.searchText
        defer {
            coordinator.searchText = searchText
            window.setFrame(frame, display: false)
            NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
        }
        let resizedHeight = min(500, window.maxSize.height)
        window.setContentSize(NSSize(width: window.frame.width, height: resizedHeight))
        NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
        coordinator.searchText = "无匹配结果-\(UUID().uuidString)"
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        XCTAssertEqual(window.frame.height, resizedHeight, accuracy: 1,
                       "搜索结果变少时应保留用户调整的高度")
    }
}
