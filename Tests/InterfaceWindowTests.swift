import AppKit
import SwiftUI
import XCTest
@testable import MenuBarExecutor

@MainActor
final class InterfaceWindowTests: XCTestCase {
    func testResultPopoverDoesNotUseGraySystemButtonFills() async throws {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            try await assertResultPopoverActionColors(appearance: appearance)
        }
    }

    private func assertResultPopoverActionColors(appearance: NSAppearance.Name) async throws {
        let command = Command(name: "当前分支", command: "printf test", autoExecute: true)
        let window = NSWindow(contentRect: NSRect(x: 200, y: 400, width: 600, height: 36),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.isReleasedWhenClosed = false
        defer { window.orderOut(nil) }
        let host = NSHostingView(rootView: CommandPaletteRow(command: command, displayIndex: 1,
            isSelected: false, searchText: "", autoExecuteState: .success("feature/my_branch")))
        window.contentView = host
        window.setContentSize(NSSize(width: 600, height: 36))
        window.makeKeyAndOrderFront(nil)
        for _ in 0..<10 {
            host.layoutSubtreeIfNeeded()
            if descendants(host).contains(where: { $0 is PaletteResultButton }) { break }
            await nextLayout()
        }
        let result = try XCTUnwrap(descendants(host).compactMap { $0 as? PaletteResultButton }.first)
        result.performClick(nil)
        var popover: NSWindow?
        for _ in 0..<20 {
            await nextLayout()
            popover = NSApp.windows.first { $0.isVisible && String(describing: type(of: $0)).contains("Popover") }
            if popover != nil { break }
        }
        let popoverWindow = try XCTUnwrap(popover)
        defer { popoverWindow.close() }
        let content = try XCTUnwrap(popoverWindow.contentView)
        content.layoutSubtreeIfNeeded()
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("menu-bar-executor-native-reference")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(data.count, 1000, "结果浮层不能是空截图")
        let suffix = appearance == .aqua ? "light" : "dark"
        try data.write(to: folder.appendingPathComponent("result-popover-actions-\(suffix).png"))
        for (name, area) in [
            ("关闭", NSRect(x: content.bounds.width - 100, y: 20, width: 80, height: 45)),
            ("复制结果", NSRect(x: 20, y: content.bounds.height - 60, width: 110, height: 45))
        ] {
            XCTAssertLessThan(longestGrayFill(in: bitmap, area: area, viewSize: content.bounds.size), 20,
                              "\(name) 应使用设计稿的透明或表面色，不能出现连续的系统灰色填充")
        }
    }

    private func longestGrayFill(in bitmap: NSBitmapImageRep, area: NSRect, viewSize: NSSize) -> CGFloat {
        let scaleX = CGFloat(bitmap.pixelsWide) / viewSize.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / viewSize.height
        var longest = 0
        for y in Int(area.minY * scaleY)..<min(bitmap.pixelsHigh, Int(area.maxY * scaleY)) {
            var run = 0
            for x in Int(area.minX * scaleX)..<min(bitmap.pixelsWide, Int(area.maxX * scaleX)) {
                let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
                let gray = color.map {
                    let components = [$0.redComponent, $0.greenComponent, $0.blueComponent]
                    return $0.alphaComponent > 0.99 && components.min()! > 0.3 && components.max()! < 0.9
                        && components.max()! - components.min()! < 0.015
                } ?? false
                run = gray ? run + 1 : 0
                longest = max(longest, run)
            }
        }
        return CGFloat(longest) / scaleX
    }

    func testShortCommandEditorFitsContentInsteadOfFillingItsHeightLimit() async {
        let command = Command(name: "启动 Docker 服务", command: "open -a Docker", group: "开发工具")
        let host = NSHostingView(rootView: CommandEditorView(command: command,
            onSave: { _ in true }, onDelete: { true }))
        host.frame = NSRect(x: 0, y: 0, width: 620, height: 740)
        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            await nextLayout()
        }
        XCTAssertLessThan(host.fittingSize.height, 710,
                          "短命令应接近设计稿的内容高度，不能把 740 点上限当成固定高度")
        XCTAssertGreaterThan(host.fittingSize.height, 500,
                             "表单及底部操作不能在测量期间折叠")
    }

    func testAutoResultNeverUnderlinesItsTextWhenHoveredOrFocused() async throws {
        let command = Command(name: "当前分支", command: "printf test", autoExecute: true)
        let output = "feature/my_branch"
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 36),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.orderOut(nil) }
        let host = NSHostingView(rootView: CommandPaletteRow(command: command, displayIndex: 1,
            isSelected: false, searchText: "", autoExecuteState: .success(output)))
        window.contentView = host
        window.setContentSize(NSSize(width: 600, height: 36))
        window.orderFront(nil)
        var resultButton: PaletteResultButton?
        for _ in 0..<10 {
            host.layoutSubtreeIfNeeded()
            resultButton = descendants(host).compactMap { $0 as? PaletteResultButton }.first
            if resultButton != nil { break }
            await nextLayout()
        }
        let button = try XCTUnwrap(resultButton)

        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            window.appearance = NSAppearance(named: appearance)
            for state in ["normal", "hovered", "focused", "blurred"] {
                window.makeFirstResponder(nil)
                button.updateResult(text: output, hovered: state == "hovered")
                if state == "focused" { XCTAssertTrue(window.makeFirstResponder(button)) }
                if state == "blurred" {
                    XCTAssertTrue(window.makeFirstResponder(button))
                    window.makeFirstResponder(nil)
                }
                XCTAssertEqual(button.attributedTitle.string, output, "不能移除结果原文中的下划线字符")
                button.attributedTitle.enumerateAttribute(.underlineStyle,
                    in: NSRange(location: 0, length: button.attributedTitle.length)) { value, _, _ in
                    XCTAssertEqual((value as? NSNumber)?.intValue ?? 0, 0,
                                   "\(appearance.rawValue) / \(state)：自动执行结果不能添加下划线装饰")
                }
            }
        }
    }

    func testLongAutoResultUsesSpaceBesideShortTitle() async throws {
        let command = Command(name: "IP", command: "printf test", autoExecute: true)
        let output = String(repeating: "192.168.31.108 / ", count: 8)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 36),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.orderOut(nil) }
        let host = NSHostingView(rootView: CommandPaletteRow(command: command, displayIndex: 1,
            isSelected: false, searchText: "", autoExecuteState: .success(output)))
        window.contentView = host
        window.setContentSize(NSSize(width: 560, height: 36))
        window.orderFront(nil)
        await nextLayout()
        host.layoutSubtreeIfNeeded()
        let result = try XCTUnwrap(descendants(host).compactMap { $0 as? NSButton }.first {
            $0.title == output
        })
        let frame = result.convert(result.bounds, to: host)
        XCTAssertGreaterThan(frame.width, 400, "短标题旁的空白应供长结果使用")
        XCTAssertGreaterThan(frame.minX, 40, "结果不能覆盖左侧标题")
        XCTAssertLessThan(frame.minX, 70, "结果应扩展到标题右侧，仅保留间隔")
        XCTAssertLessThan(frame.maxX, 540, "结果右侧应保留快捷键区域")
    }

    func testAutoResultsRenderAtPanelWidths() async throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("menu-bar-executor-native-reference")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let short = Command(name: "IP", command: "printf test", autoExecute: true)
        let long = Command(name: "当前开发环境的网络连接状态与地址", command: "printf test", autoExecute: true)
        let output = "192.168.31.108 / en0 / 当前网络连接正常，以下内容超出行内显示范围"
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let suffix = appearance == .aqua ? "light" : "dark"
            for width in [360, 600, 800] {
                try await snapshot(VStack(spacing: 0) {
                    CommandPaletteRow(command: short, displayIndex: 1, isSelected: true, searchText: "", autoExecuteState: .success(output))
                    CommandPaletteRow(command: long, displayIndex: 2, isSelected: false, searchText: "", autoExecuteState: .success(output))
                    CommandPaletteRow(command: short, displayIndex: 3, isSelected: false, searchText: "", autoExecuteState: .success("main"))
                    CommandPaletteRow(command: short, displayIndex: 4, isSelected: false, searchText: "", autoExecuteState: .success("第一行\n第二行\n第三行"))
                    CommandPaletteRow(command: short, displayIndex: 5, isSelected: false, searchText: "", autoExecuteState: .loading)
                    CommandPaletteRow(command: short, displayIndex: 6, isSelected: false, searchText: "", autoExecuteState: .success(""))
                    CommandPaletteRow(command: short, displayIndex: 10, isSelected: false, searchText: "", autoExecuteState: .failure(output))
                }.background(InterfaceStyle.surface), size: NSSize(width: width, height: 252),
                name: "palette-long-results-\(suffix)-\(width)", folder: folder, appearance: appearance)
            }
        }
    }

    func testSettingsWindowUsesOneTitlebarAndItsCloseButtonWorks() async throws {
        let controller = SettingsWindowController.shared
        controller.showWindow()
        let window = try XCTUnwrap(controller.window)
        await nextLayout()
        let content = try XCTUnwrap(window.contentView)
        XCTAssertEqual(content.bounds.height, window.frame.height, accuracy: 1,
                       "原型的标题区已在内容中，不能再保留一条系统标题栏")
        let settingsClose = await waitForCloseButton(in: content)
        let close = try XCTUnwrap(settingsClose, "标题区应使用能关闭真实窗口的自绘按钮")
        assertHeaderPinnedToTop(close, in: content, "标题区应贴住窗口顶边，不能再叠加一条系统标题栏的空白")
        close.performClick(nil)
        XCTAssertFalse(window.isVisible)
    }

    func testInlineGroupTextFieldStaysFocusedAndHandlesSubmitCancelAndBlur() async throws {
        var draft = "开发工具"
        var committed: [String] = []
        var cancelledCount = 0

        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 320, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let binding = Binding(get: { draft }, set: { draft = $0 })
        let host = NSHostingView(rootView: InlineGroupTextField(
            placeholder: "分组名称",
            text: binding,
            selectAllOnFocus: true,
            onCommit: { committed.append(draft) },
            onCancel: { cancelledCount += 1 }
        ).frame(width: 180, height: 24))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        for _ in 0..<10 {
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        let field = try XCTUnwrap(descendants(host).compactMap { $0 as? NSTextField }.first)
        XCTAssertTrue(committed.isEmpty, "刚进入行内编辑时不能因焦点抖动自动提交退出")
        XCTAssertEqual(cancelledCount, 0)
        XCTAssertTrue(
            window.firstResponder === field || window.firstResponder === field.currentEditor(),
            "行内输入框挂载后应自动获得窗口焦点"
        )

        // 模拟编辑并回车提交
        field.stringValue = "核心工具"
        field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))
        let handledReturn = field.delegate?.control?(field, textView: field.currentEditor() as? NSTextView ?? NSTextView(), doCommandBy: #selector(NSResponder.insertNewline(_:)))
        XCTAssertEqual(handledReturn, true)
        XCTAssertEqual(committed, ["核心工具"])
        XCTAssertEqual(cancelledCount, 0)
    }

    func testInlineGroupTextFieldEscapeCancelsWithoutCommitting() async throws {
        var draft = "开发工具"
        var committedCount = 0
        var cancelledCount = 0

        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 320, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let binding = Binding(get: { draft }, set: { draft = $0 })
        let host = NSHostingView(rootView: InlineGroupTextField(
            placeholder: "分组名称",
            text: binding,
            selectAllOnFocus: true,
            onCommit: { committedCount += 1 },
            onCancel: { cancelledCount += 1 }
        ).frame(width: 180, height: 24))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        for _ in 0..<10 {
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        let field = try XCTUnwrap(descendants(host).compactMap { $0 as? NSTextField }.first)
        let handledEsc = field.delegate?.control?(field, textView: field.currentEditor() as? NSTextView ?? NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:)))
        XCTAssertEqual(handledEsc, true)
        // 取消后再触发失焦不得补发 commit
        window.makeFirstResponder(nil)
        await nextLayout()
        XCTAssertEqual(cancelledCount, 1)
        XCTAssertEqual(committedCount, 0)
    }

    func testInlineGroupTextFieldBlurCommitsAfterFocus() async throws {
        var draft = "开发工具"
        var committed: [String] = []

        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 320, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let binding = Binding(get: { draft }, set: { draft = $0 })
        let host = NSHostingView(rootView: InlineGroupTextField(
            placeholder: "分组名称",
            text: binding,
            selectAllOnFocus: true,
            onCommit: { committed.append(draft) },
            onCancel: {}
        ).frame(width: 180, height: 24))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        for _ in 0..<10 {
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        let field = try XCTUnwrap(descendants(host).compactMap { $0 as? NSTextField }.first)
        field.stringValue = "改名后"
        field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))
        window.makeFirstResponder(nil)
        await nextLayout()
        XCTAssertEqual(committed, ["改名后"], "真实获得焦点后再失焦应提交当前草稿")
    }

    func testInlineGroupTextFieldClickingOutsideCommitsWhileClickingInsideKeepsEditing() async throws {
        var draft = "开发工具"
        var committed: [String] = []

        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 320, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let binding = Binding(get: { draft }, set: { draft = $0 })
        let host = NSHostingView(rootView: VStack(spacing: 0) {
            InlineGroupTextField(
                placeholder: "分组名称",
                text: binding,
                selectAllOnFocus: true,
                onCommit: { committed.append(draft) },
                onCancel: {}
            )
            .frame(width: 180, height: 24)
            Color.clear.frame(height: 100)
        }.frame(width: 320, height: 160))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        for _ in 0..<10 {
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        let field = try XCTUnwrap(descendants(host).compactMap { $0 as? NSTextField }.first)
        field.stringValue = "点击外部提交"
        field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))

        // 点击输入框内部不应提交
        let fieldRectInWindow = field.convert(field.bounds, to: nil)
        let insidePoint = NSPoint(x: fieldRectInWindow.midX, y: fieldRectInWindow.midY)
        let insideEvent = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: insidePoint,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        NSApp.sendEvent(insideEvent)
        await nextLayout()
        XCTAssertTrue(committed.isEmpty, "点击输入框内部不应结束重命名")

        // 点击窗口空白处（非可聚焦控件）必须自动确认重命名
        let outsidePoint = NSPoint(x: 160, y: 20)
        XCTAssertFalse(fieldRectInWindow.contains(outsidePoint))
        let outsideEvent = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: outsidePoint,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 1
        ))
        NSApp.sendEvent(outsideEvent)
        await nextLayout()
        XCTAssertEqual(committed, ["点击外部提交"], "点击输入框以外的窗口空白处应自动确认重命名")
    }

    func testHistoryWindowUsesOneTitlebarAfterReopening() async throws {
        let controller = HistoryWindowController.shared
        controller.showWindow()
        let window = try XCTUnwrap(NSApp.windows.first { $0.title == "执行历史" })
        window.performClose(nil)
        controller.showWindow()
        await nextLayout()
        XCTAssertTrue(window.isVisible)
        let content = try XCTUnwrap(window.contentView)
        XCTAssertEqual(content.bounds.height, window.frame.height, accuracy: 1,
                       "重新打开历史窗口仍应采用原型内置标题区")
        let historyClose = await waitForCloseButton(in: content)
        let close = try XCTUnwrap(historyClose, "标题区应使用能关闭真实窗口的自绘按钮")
        assertHeaderPinnedToTop(close, in: content, "重新打开历史窗口的标题区仍应贴住窗口顶边")
        window.performClose(nil)
    }

    /// SwiftUI 在窗口上屏后才挂载自绘窗口按钮，等几个主循环周期再查找。
    private func waitForCloseButton(in content: NSView) async -> NSButton? {
        for _ in 0..<10 {
            content.layoutSubtreeIfNeeded()
            if let button = descendants(content).compactMap({ $0 as? NSButton }).first(where: {
                $0.accessibilitySubrole() == .closeButton
            }) {
                return button
            }
            await nextLayout()
        }
        return nil
    }

    /// NSHostingView 用翻转坐标：55 点标题区里自绘按钮中心距顶 27.5 点上下 1 点，系统标题栏的安全区会把它再推下 32 点。
    private func assertHeaderPinnedToTop(_ close: NSButton, in content: NSView, _ message: String) {
        XCTAssertEqual(close.convert(close.bounds, to: content).midY, 27.5, accuracy: 2, message)
    }

    /// 保存真实 NSHostingView 渲染供逐屏核对，不以像素常量代替视觉验收。
    func testReferenceViewsRenderAtNormalAndMinimumSizes() async throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("menu-bar-executor-native-reference")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fixtureURL = folder.appendingPathComponent("settings.json")
        var fixture = AppSettings()
        fixture.autoCheckUpdates = false
        fixture.commands = [
            Command(name: "当前 IP 地址", command: "printf '192.168.31.108'", autoExecute: true, group: "状态速览"),
            Command(name: "查看 Git 分支", command: "printf main", autoExecute: true, group: "状态速览"),
            Command(name: "启动 Docker 服务", command: "printf Docker", group: "开发工具"),
            Command(name: "启动本地开发环境", command: "printf dev", group: "开发工具"),
            Command(name: "清理 Xcode 缓存", command: "printf cache", group: "开发工具"),
            Command(name: "显示隐藏文件", command: "printf Finder", group: "日常操作"),
            Command(name: "刷新 DNS 缓存", command: "printf DNS", group: "日常操作"),
            Command(name: "打开下载文件夹", command: "printf Downloads", group: "日常操作")
        ]
        try JSONEncoder().encode(fixture).write(to: fixtureURL)
        let settings = AppSettingsManager(filePath: fixtureURL, enableFileMonitoring: false)
        let coordinator = PaletteCoordinator(settingsManager: settings, runAutoCommand: { _, _ in
            XCTFail("截图验收不能运行命令")
            return {}
        })
        coordinator.autoExecuteResults[fixture.commands[0].id] = .success("192.168.31.108")
        coordinator.autoExecuteResults[fixture.commands[1].id] = .success("main")
        let sample = Command(name: "启动 Docker 服务", command: "open -a Docker", group: "开发工具", directExecution: true)
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let suffix = appearance == .aqua ? "light" : "dark"
            for (label, size) in [
                ("normal", NSSize(width: 900, height: 640)),
                ("narrow", NSSize(width: 640, height: 640)),
                ("short", NSSize(width: 900, height: 420)),
                ("minimum", NSSize(width: 640, height: 420))
            ] {
                try await snapshot(SettingsView(), size: size, name: "commands-\(suffix)-\(label)", folder: folder, appearance: appearance)
                try await snapshot(VStack(spacing: 0) { WindowHeader(title: "设置"); GeneralSettingsView() }, size: size,
                                   name: "general-\(suffix)-\(label)", folder: folder, appearance: appearance)
                try await snapshot(HistoryView(), size: NSSize(width: label == "normal" || label == "short" ? 960 : 640, height: size.height == 640 ? 680 : 420),
                                   name: "history-\(suffix)-\(label)", folder: folder, appearance: appearance)
            }
            try await snapshot(CommandPaletteView(coordinator: coordinator), size: NSSize(width: 600, height: 503),
                               name: "palette-\(suffix)", folder: folder, appearance: appearance)
            for (label, size) in [
                ("narrow", NSSize(width: 360, height: 503)),
                ("short", NSSize(width: 600, height: 250)),
                ("minimum", NSSize(width: 360, height: 250))
            ] {
                try await snapshot(CommandPaletteView(coordinator: coordinator), size: size,
                                   name: "palette-\(suffix)-\(label)", folder: folder, appearance: appearance)
            }
            try await snapshot(CommandEditorView(command: sample, onSave: { _ in true }, onDelete: { true }),
                               size: NSSize(width: 620, height: 740), name: "editor-\(suffix)", folder: folder, appearance: appearance, fitHeight: true)
            for hovered in [false, true] {
                try await snapshot(CommandPaletteRow(command: sample, displayIndex: 1, isSelected: true,
                    searchText: "", autoExecuteState: .success("192.168.31.108")),
                    size: NSSize(width: 600, height: 36),
                    name: "palette-result-\(hovered ? "hover" : "focus")-\(suffix)", folder: folder, appearance: appearance) { host in
                        guard let button = self.descendants(host).compactMap({ $0 as? PaletteResultButton }).first else {
                            XCTFail("结果查看入口必须存在")
                            return
                        }
                        if hovered { button.updateResult(text: "192.168.31.108", hovered: true, selected: true) }
                        else { XCTAssertTrue(button.window?.makeFirstResponder(button) == true) }
                    }
            }
            try await snapshot(VStack(spacing: 0) {
                CommandPaletteRow(command: sample, displayIndex: 1, isSelected: true, searchText: "Docker", autoExecuteState: nil)
                CommandPaletteRow(command: sample, displayIndex: 2, isSelected: false, searchText: "Docker", autoExecuteState: nil)
            }, size: NSSize(width: 600, height: 72),
            name: "palette-search-\(suffix)", folder: folder, appearance: appearance)
            try await snapshot(VStack(spacing: 0) {
                CommandPaletteRow(command: sample, displayIndex: 1, isSelected: true, searchText: "", autoExecuteState: .success("192.168.31.108"))
                CommandPaletteRow(command: sample, displayIndex: 2, isSelected: false, searchText: "", autoExecuteState: .loading)
                CommandPaletteRow(command: sample, displayIndex: 3, isSelected: false, searchText: "", autoExecuteState: .failure("执行失败"))
                CommandPaletteRow(command: sample, displayIndex: 4, isSelected: false, searchText: "", autoExecuteState: .success(""))
            }.padding(8).background(InterfaceStyle.surface), size: NSSize(width: 600, height: 160),
            name: "palette-results-\(suffix)", folder: folder, appearance: appearance)
        }
        print("Native interface snapshots: \(folder.path)")
    }

    private func snapshot<Content: View>(_ content: Content, size: NSSize, name: String, folder: URL, appearance: NSAppearance.Name, fitHeight: Bool = false, prepare: ((NSView) -> Void)? = nil) async throws {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.isReleasedWhenClosed = false
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }
        let host = NSHostingView(rootView: content)
        window.contentView = host
        window.setContentSize(size)
        window.orderFront(nil)
        await nextLayout()
        host.layoutSubtreeIfNeeded()
        if fitHeight {
            for _ in 0..<5 {
                await nextLayout()
                host.layoutSubtreeIfNeeded()
            }
            window.setContentSize(NSSize(width: size.width, height: host.fittingSize.height))
            host.layoutSubtreeIfNeeded()
        }
        prepare?(host)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(data.count, 1000, "不能把空图片当作界面渲染成功")
        try data.write(to: folder.appendingPathComponent(name + ".png"))
    }

    private func nextLayout() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}
