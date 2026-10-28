import AppKit
import XCTest
@testable import MenuBarExecutor

final class CommandPaletteWindowTests: XCTestCase {
    @MainActor
    func testPaletteBackgroundStartsNativeWindowDrag() async throws {
        let window = try XCTUnwrap(CommandPaletteWindowController.shared.window)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        let content = try XCTUnwrap(window.contentView)
        let dragWindow = DragRecordingPanel(contentRect: window.frame, styleMask: window.styleMask, backing: .buffered, defer: false)
        dragWindow.isMovableByWindowBackground = true
        dragWindow.contentView = content
        defer {
            dragWindow.orderOut(nil)
            dragWindow.contentView = nil
            window.contentView = content
        }
        content.layoutSubtreeIfNeeded()
        dragWindow.orderFront(nil)
        // 从窗口分发鼠标事件，覆盖搜索区边缘与底栏空白，不能绕过原生事件分发。
        let points = [NSPoint(x: 12, y: content.bounds.height - 26),
                      NSPoint(x: content.bounds.midX + 30, y: 16)]
        for point in points {
            let target = try XCTUnwrap(content.hitTest(point))
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: point,
                modifierFlags: [], timestamp: 0, windowNumber: dragWindow.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
            dragWindow.dragEvent = nil
            dragWindow.sendEvent(event)
            XCTAssertTrue(dragWindow.dragEvent === event,
                          "非控件区域应启动原生窗口拖拽，命中 \(type(of: target))")
        }
    }

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

@MainActor
private final class DragRecordingPanel: NSPanel {
    var dragEvent: NSEvent?

    override func performDrag(with event: NSEvent) {
        dragEvent = event
    }
}
