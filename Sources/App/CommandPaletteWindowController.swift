import AppKit
import SwiftUI
import Combine

// MARK: - KeyCode 常量
enum KeyCode {
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
    static let upArrow: UInt16 = 126
    static let downArrow: UInt16 = 125
    static let tab: UInt16 = 48
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
        guard !KeyDownMonitor.hasMarkedText(in: window?.firstResponder) else {
            return super.performKeyEquivalent(with: event)
        }
        guard !CommandPaletteWindowController.shared.resultPopoverIsPresented,
              window?.attachedSheet == nil else { return super.performKeyEquivalent(with: event) }
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

        // 拦截 ⌘+数字（执行当前搜索结果的前九条命令）
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           let num = Int(chars),
           (1...9).contains(num) {
            Task { @MainActor in
                let coordinator = PaletteCoordinator.shared
                if let cmd = coordinator.listModel.command(atQuickSelectPosition: num) {
                    coordinator.execute(cmd)
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

    /// 预热：建窗（不显示）并强制一次离屏布局，首次呼出免付建窗与首布局成本
    static func prewarm() {
        _ = shared
        shared.panel.contentView?.layoutSubtreeIfNeeded()
    }

    private var panel: KeyPanel!
    private var paletteView: PaletteContainerView!
    private let settings = AppSettingsManager.shared
    private var previousInputSourceID: String?
    private var preferredHeight: CGFloat?
    private var cancellables = Set<AnyCancellable>()
    private let resultControls = NSHashTable<PaletteResultButton>.weakObjects()
    var resultPopoverIsPresented = false
    var isSearchFocused = true
    var setSearchFocus: ((Bool) -> Void)?
    var lastPointerLocation = NSEvent.mouseLocation

    private lazy var keyMonitor = KeyDownMonitor { [weak self] event in
        guard let self, self.panel.isKeyWindow,
              self.panel.attachedSheet == nil, !self.resultPopoverIsPresented else { return event }
        self.lastPointerLocation = NSEvent.mouseLocation

        let keyCode = event.keyCode

        if keyCode == KeyCode.tab {
            let buttons = self.resultControls.allObjects.filter { $0.window != nil && !$0.isHiddenOrHasHiddenAncestor }.sorted {
                $0.convert($0.bounds, to: self.paletteView).minY > $1.convert($1.bounds, to: self.paletteView).minY
            }
            let backwards = event.modifierFlags.contains(.shift)
            if let current = self.panel.firstResponder as? PaletteResultButton,
               let index = buttons.firstIndex(of: current) {
                let next = index + (backwards ? -1 : 1)
                if buttons.indices.contains(next) { self.focusResultButton(buttons[next]) }
                else if backwards { self.panel.selectPreviousKeyView(nil) }
                else { self.panel.selectNextKeyView(nil) }
            } else if self.isSearchFocused, let target = backwards ? buttons.last : buttons.first {
                self.focusResultButton(target)
            } else if backwards { self.panel.selectPreviousKeyView(nil) }
            else { self.panel.selectNextKeyView(nil) }
            return nil
        }

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
        if keyCode == KeyCode.returnKey && self.isSearchFocused && !(self.panel.firstResponder is PaletteResultButton) {
            PaletteCoordinator.shared.executeSelected()
            return nil
        }

        // 其他键正常传递
        return event
    }
    private init() {
        // 获取保存的尺寸或使用默认值
        let savedSize = settings.settings.paletteSize ?? NSSize(width: PaletteConfig.defaultWidth, height: PaletteConfig.defaultHeight)
        preferredHeight = settings.settings.paletteSize?.height

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
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: PaletteConfig.minWidth, height: PaletteConfig.minHeight)
        panel.maxSize = NSSize(width: PaletteConfig.maxWidth, height: PaletteConfig.maxHeight)

        super.init(window: panel)

        PaletteCoordinator.shared.$listModel
            .map(\.items)
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.fitContent() }
            }.store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidEndLiveResize(_:)),
            name: NSWindow.didEndLiveResizeNotification,
            object: panel
        )

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
        // 已可见时不再重置透明度，避免打断正在进行的淡入造成闪烁
        let isFreshShow = !isPanelVisible

        // 触发后台刷新配置（外部修改由监听兜底，读盘不阻塞本次显示）
        settings.reloadSilent()
        PaletteCoordinator.shared.reset()

        // 保存当前输入法（防止 show() 被重复调用时覆盖原始输入法记录）
        if isFreshShow {
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
        fitContent()
        lastPointerLocation = NSEvent.mouseLocation
        // 先置透明再显示，避免 orderFront 以全不透明闪现一帧
        if isFreshShow { panel.alphaValue = 0 }
        panel.makeKeyAndOrderFront(nil)
        keyMonitor.start()
        if isFreshShow {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = PaletteConfig.fadeDuration
                panel.animator().alphaValue = 1
            }
        }

        // 下一 runloop 执行自动命令，让面板先开始渲染
        // 不能依赖 SwiftUI .onAppear，因为 NSPanel show/hide 循环不会重复触发 .onAppear
        DispatchQueue.main.async {
            PaletteCoordinator.shared.executeAutoCommands()
        }
    }

    /// 同步 orderOut（无动画），返回后面板已从屏幕移除，调用方可立即继续后续动作
    func hide() {
        guard isPanelVisible else { return }
        keyMonitor.stop()

        // 捕获并立即清空，防止 windowDidResignKey → hide() 重复恢复
        let restoreID = previousInputSourceID
        previousInputSourceID = nil

        let frame = panel.frame
        let frameIsValid = isPositionValid(at: frame.origin)

        // 位置保存在窗口消失后执行，磁盘写不阻塞关闭
        panel.orderOut(nil)
        if frameIsValid {
            settings.updatePaletteFrame(origin: frame.origin, size: frame.size)
        }

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

    private func isPositionValid(at point: CGPoint) -> Bool {
        let frame = NSRect(origin: point, size: panel.frame.size)
        return NSScreen.screens.contains { $0.frame.intersects(frame) }
    }

    func focusResultButton(_ button: NSButton) {
        setSearchFocus?(false)
        DispatchQueue.main.async { button.window?.makeFirstResponder(button) }
    }

    func registerResultButton(_ button: PaletteResultButton) {
        resultControls.add(button)
    }

    private func fitContent() {
        guard !panel.inLiveResize else { return }
        let items = PaletteCoordinator.shared.listModel.items
        let screen = panel.screen ?? NSScreen.main
        let available = screen?.visibleFrame ?? panel.frame
        let listHeight = items.isEmpty ? CGFloat(160) : items.enumerated().reduce(CGFloat(21)) { height, entry in
            switch entry.element {
            case .groupHeader: return height + 32
            case .command: return height + 36
            }
        }
        let fixedHeight: CGFloat = 60 + 41 + 2
        let contentHeight = fixedHeight + min(listHeight, 410)
        let height = min(max(preferredHeight ?? contentHeight, PaletteConfig.minHeight), PaletteConfig.maxHeight, available.height)
        let width = min(max(panel.frame.width, PaletteConfig.minWidth), PaletteConfig.maxWidth, available.width)
        var frame = panel.frame
        frame.origin.y += frame.height - height
        frame.size = NSSize(width: width, height: height)
        frame.origin.x = min(max(frame.minX, available.minX), available.maxX - width)
        frame.origin.y = min(max(frame.minY, available.minY), available.maxY - height)
        panel.minSize = NSSize(width: min(PaletteConfig.minWidth, available.width), height: min(PaletteConfig.minHeight, available.height))
        panel.maxSize = NSSize(width: min(PaletteConfig.maxWidth, available.width), height: min(PaletteConfig.maxHeight, available.height))
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)
        panel.recalculateKeyViewLoop()
    }

    @objc private func windowDidEndLiveResize(_ notification: Notification) {
        preferredHeight = panel.frame.height
        fitContent()
    }

    func closeIfInactive() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.panel.isKeyWindow, !self.resultPopoverIsPresented,
                  self.panel.attachedSheet == nil else { return }
            self.hide()
        }
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        closeIfInactive()
    }
}
