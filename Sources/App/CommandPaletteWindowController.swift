import AppKit
import SwiftUI

// MARK: - KeyCode 常量
enum KeyCode {
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
    static let upArrow: UInt16 = 126
    static let downArrow: UInt16 = 125
    static let settingsShortcut = ","  // ⌘+, 打开设置
}

// MARK: - 自定义 Panel（支持无标题栏时接收键盘事件）
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 处理键盘事件的 NSView，嵌入 SwiftUI 视图
final class PaletteContainerView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 处理 ⌘+, (打开设置)
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           chars == KeyCode.settingsShortcut {
            Task { @MainActor in
                CommandPaletteWindowController.shared.hide()
                SettingsWindowController.shared.showWindow()
            }
            return true
        }

        // 拦截 ⌘+数字（执行相对于可见区域的命令）
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           let num = Int(chars),
           (1...9).contains(num) {
            Task { @MainActor in
                let coordinator = PaletteCoordinator.shared
                let commands = coordinator.filteredCommands
                // 计算实际索引：firstVisibleIndex + (num - 1)
                let actualIndex = coordinator.firstVisibleIndex + (num - 1)
                if actualIndex < commands.count {
                    coordinator.execute(commands[actualIndex])
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

    private var panel: KeyPanel!
    private var paletteView: PaletteContainerView!
    private let settings = AppSettingsManager.shared
    private var eventMonitor: Any?
    private var previousInputSourceID: String?
    private init() {
        // 获取保存的尺寸或使用默认值
        let savedSize = settings.settings.paletteSize ?? NSSize(width: PaletteConfig.defaultWidth, height: PaletteConfig.defaultHeight)

        let contentView = CommandPaletteView()
        let hostingView = NSHostingView(rootView: contentView)

        // 用 PaletteContainerView 包裹 hostingView 以处理键盘事件
        paletteView = PaletteContainerView(frame: NSRect(origin: .zero, size: savedSize))
        paletteView.addSubview(hostingView)
        hostingView.frame = paletteView.bounds
        hostingView.autoresizingMask = [.width, .height]

        panel = KeyPanel(
            contentRect: NSRect(origin: .zero, size: savedSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.contentView = paletteView
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = false  // 允许无标题栏面板成为 key window
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: PaletteConfig.minWidth, height: PaletteConfig.minHeight)
        panel.maxSize = NSSize(width: PaletteConfig.maxWidth, height: PaletteConfig.maxHeight)

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
        // eventMonitor 的移除可以在任何线程进行
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isPanelVisible: Bool {
        panel.isVisible
    }

    func toggle() {
        if isPanelVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        // 从磁盘重新加载配置，确保显示最新的命令（解决外部编辑文件后的刷新问题）
        settings.reloadSilent()
        PaletteCoordinator.shared.reset()

        // 保存当前输入法（防止 show() 被重复调用时覆盖原始输入法记录）
        if !isPanelVisible {
            previousInputSourceID = InputSourceHelper.currentInputSourceID()
        }

        // 切换到默认输入法
        if let inputSourceID = settings.settings.defaultInputSourceID,
           previousInputSourceID != inputSourceID {
            _ = InputSourceHelper.switchToInputSource(id: inputSourceID)
        }

        // 恢复上次位置或居中
        if let pos = settings.settings.palettePosition, isPositionValid(at: pos) {
            panel.setFrameOrigin(pos)
        } else {
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)
        setupEventMonitor()
    }

    func hide() {
        guard isPanelVisible else { return }
        removeEventMonitor()

        // 捕获并立即清空，防止 windowDidResignKey → hide() 重复恢复
        let restoreID = previousInputSourceID
        previousInputSourceID = nil

        // 保存位置和尺寸
        let frame = panel.frame
        if isPositionValid(at: frame.origin) {
            // 先从磁盘加载最新配置，防止用旧数据覆盖外部修改
            settings.load(notifyError: false)
            settings.updatePaletteFrame(origin: frame.origin, size: frame.size)
        }
        panel.orderOut(nil)

        // 在面板完全隐藏、系统窗口管理完成后，再恢复输入法。
        // 必须在 orderOut 之后执行：.nonactivatingPanel 的 orderOut 会触发系统
        // 恢复活跃应用的记忆输入法，覆盖我们在 orderOut 之前设置的输入法。
        if let restoreID {
            DispatchQueue.main.async {
                guard InputSourceHelper.currentInputSourceID() != restoreID else { return }
                _ = InputSourceHelper.switchToInputSource(id: restoreID)
            }
        }
    }

    private func setupEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }

            let keyCode = event.keyCode

            // 拦截导航键
            if keyCode == KeyCode.upArrow {
                PaletteCoordinator.shared.moveUp()
                return nil
            }
            if keyCode == KeyCode.downArrow {
                PaletteCoordinator.shared.moveDown()
                return nil
            }
            if keyCode == KeyCode.escape {
                if PaletteCoordinator.shared.searchText.isEmpty {
                    self.hide()
                } else {
                    PaletteCoordinator.shared.clearSearch()
                }
                return nil
            }
            if keyCode == KeyCode.returnKey {
                PaletteCoordinator.shared.executeSelected()
                return nil
            }

            // 其他键正常传递
            return event
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func isPositionValid(at point: CGPoint) -> Bool {
        let frame = NSRect(origin: point, size: panel.frame.size)
        return NSScreen.screens.contains { $0.frame.intersects(frame) }
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
