import AppKit
import SwiftUI

// MARK: - KeyCode 常量
private enum KeyCode {
    static let escape: UInt16 = 53
    static let tab: UInt16 = 48
    static let returnKey: UInt16 = 36
    static let upArrow: UInt16 = 126
    static let downArrow: UInt16 = 125
}

/// 处理键盘事件的 NSView，嵌入 SwiftUI 视图
final class PaletteContainerView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode

        if keyCode == KeyCode.escape {
            CommandPaletteWindowController.shared.hide()
            return
        }

        // Tab: 补全
        if keyCode == KeyCode.tab {
            Task { @MainActor in
                PaletteCoordinator.shared.tabComplete()
            }
            return
        }

        // Return: 执行选中命令
        if keyCode == KeyCode.returnKey {
            Task { @MainActor in
                PaletteCoordinator.shared.executeSelected()
            }
            return
        }

        // Up/Down: 列表导航
        if keyCode == KeyCode.upArrow {
            Task { @MainActor in
                PaletteCoordinator.shared.moveUp()
            }
            return
        }

        if keyCode == KeyCode.downArrow {
            Task { @MainActor in
                PaletteCoordinator.shared.moveDown()
            }
            return
        }

        // 其他按键传递给 text field
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 拦截 ⌘+数字
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           let num = Int(chars),
           (1...9).contains(num) {
            Task { @MainActor in
                let commands = PaletteCoordinator.shared.filteredCommands
                if num <= commands.count {
                    PaletteCoordinator.shared.execute(commands[num - 1])
                }
            }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
final class CommandPaletteWindowController: NSWindowController {
    static let shared = CommandPaletteWindowController()

    private var panel: NSPanel!
    private var paletteView: PaletteContainerView!
    private let settings = AppSettingsManager.shared

    private init() {
        let contentView = CommandPaletteView()
        let hostingView = NSHostingView(rootView: contentView)

        // 用 PaletteContainerView 包裹 hostingView 以处理键盘事件
        paletteView = PaletteContainerView(frame: NSRect(x: 0, y: 0, width: PaletteConfig.width, height: PaletteConfig.totalHeight))
        paletteView.addSubview(hostingView)
        hostingView.frame = paletteView.bounds
        hostingView.autoresizingMask = [.width, .height]

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: PaletteConfig.width, height: PaletteConfig.totalHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable],
            backing: .buffered,
            defer: false
        )

        panel.contentView = paletteView
        panel.level = .floating
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: panel)

        // 监听失焦关闭
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        // 恢复上次位置或居中
        if let pos = settings.settings.palettePosition, isPositionValid(at: pos) {
            panel.setFrameOrigin(pos)
        } else {
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)
        // 聚焦到面板
        paletteView.window?.makeFirstResponder(paletteView)
    }

    func hide() {
        // 仅当位置变化且仍在屏幕范围内时才保存
        let frame = panel.frame
        if isPositionValid(at: frame.origin) {
            let currentOrigin = frame.origin
            if settings.settings.palettePosition != currentOrigin {
                settings.settings.palettePosition = currentOrigin
                settings.save()
            }
        }
        panel.orderOut(nil)
    }

    private func isPositionValid(at point: CGPoint) -> Bool {
        let frame = NSRect(origin: point, size: panel.frame.size)
        return NSScreen.screens.contains { $0.frame.intersects(frame) }
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
