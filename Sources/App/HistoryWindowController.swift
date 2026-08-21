import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController: NSObject {
    static let shared = HistoryWindowController()

    private var window: NSWindow?
    private var hasWindowObserver = false

    private lazy var keyMonitor = KeyDownMonitor { [weak self] event in
        guard let self = self, let window = self.window, window.isKeyWindow else { return event }

        // Cmd+, 打开设置
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           chars == KeyCode.settingsShortcut {
            SettingsWindowController.shared.showWindow()
            return nil
        }

        return event
    }

    private override init() {
        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // 窗口关闭过一次后监听已被移除，幂等 start 恢复
            keyMonitor.start()
            return
        }

        let contentView = HistoryView()
        let hostingView = NSHostingView(rootView: contentView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window?.title = "执行历史"
        window?.contentView = hostingView
        window?.isReleasedWhenClosed = false
        window?.center()

        // 添加窗口关闭通知观察者（只监听自己的窗口）
        if let window = window, !hasWindowObserver {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowWillClose),
                name: NSWindow.willCloseNotification,
                object: window
            )
            hasWindowObserver = true
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        keyMonitor.start()
    }

    @objc private func windowWillClose() {
        keyMonitor.stop()
    }
}
