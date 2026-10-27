import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private lazy var keyMonitor = KeyDownMonitor { [weak self] event in
        guard let self = self, let window = self.window, window.isKeyWindow else { return event }

        // Cmd+, 重新激活窗口
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           chars == KeyCode.settingsShortcut {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return nil
        }

        return event
    }

    private init() {
        let contentView = SettingsView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 620),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 640, height: 442)
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 642)
        window.center()
        window.title = "设置"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(InterfaceStyle.material)
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false

        super.init(window: window)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        if let screen = window?.screen ?? NSScreen.main, let window {
            var frame = window.frame
            frame.size.height = min(frame.height, screen.visibleFrame.height)
            frame.origin.y = min(max(frame.origin.y, screen.visibleFrame.minY), screen.visibleFrame.maxY - frame.height)
            window.setFrame(frame, display: false)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        keyMonitor.start()
    }

    @objc private func windowWillClose() {
        keyMonitor.stop()
    }
}
