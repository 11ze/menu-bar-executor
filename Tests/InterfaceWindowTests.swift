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

    func testSettingsSearchAcceptsClickAndTyping() async throws {
        let controller = SettingsWindowController.shared
        controller.showWindow()
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        try await assertToolbarSearchFieldAcceptsClickAndTyping(in: window, placeholder: "搜索全部命令名称")
    }

    func testHistorySearchAcceptsClickAndTyping() async throws {
        let controller = HistoryWindowController.shared
        controller.showWindow()
        let window = try XCTUnwrap(NSApp.windows.first { $0.title == "执行历史" })
        defer { window.performClose(nil) }
        try await assertToolbarSearchFieldAcceptsClickAndTyping(in: window, placeholder: "搜索命令名称")
    }

    private func assertToolbarSearchFieldAcceptsClickAndTyping(in window: NSWindow, placeholder: String) async throws {
        await nextLayout()
        let content = try XCTUnwrap(window.contentView)
        content.layoutSubtreeIfNeeded()
        let field = try XCTUnwrap(descendants(content).compactMap { $0 as? NSSearchField }.first {
            $0.placeholderString == placeholder
        })
        let originalAppearance = window.appearance
        window.appearance = NSAppearance(named: .aqua)
        defer { window.appearance = originalAppearance }
        let rect = field.convert(field.bounds, to: nil)
        for point in [NSPoint(x: rect.midX, y: rect.midY), NSPoint(x: rect.minX + 10, y: rect.midY),
                      NSPoint(x: rect.midX, y: rect.maxY - 3)] {
            window.makeFirstResponder(nil)
            await nextLayout()
            XCTAssertFalse(try hasBlueTopBorder(around: field, in: content, halfHeight: 17), "搜索框失焦后应恢复普通边框")
            try clickWindow(window, at: point, postUpFirst: true)
            await nextLayout()
            let editor = try XCTUnwrap(field.currentEditor() as? NSTextView, "点击 \(point) 应开始编辑（输入区域 \(rect)）")
            XCTAssertTrue(window.firstResponder === editor)
            XCTAssertTrue(try hasBlueTopBorder(around: field, in: content, halfHeight: 17), "输入前就应显示蓝色焦点边框")
            editor.insertText("sync", replacementRange: editor.selectedRange())
            XCTAssertEqual(field.stringValue, "sync")
            let cell = try XCTUnwrap(field.cell as? NSSearchFieldCell)
            let editorBounds = editor.convert(editor.bounds, to: field)
            XCTAssertGreaterThanOrEqual(editorBounds.minX, cell.searchTextRect(forBounds: field.bounds).minX,
                                        "字段编辑器必须给放大镜留出空间")
            editor.selectAll(nil)
            editor.deleteBackward(nil)
        }

        window.makeFirstResponder(nil)
        await nextLayout()
        XCTAssertTrue(window.makeFirstResponder(field))
        await nextLayout()
        XCTAssertTrue(try hasBlueTopBorder(around: field, in: content, halfHeight: 17), "搜索框获得键盘焦点时应显示蓝色边框")
        window.makeFirstResponder(nil)
        await nextLayout()
        XCTAssertFalse(try hasBlueTopBorder(around: field, in: content, halfHeight: 17), "未输入就移走焦点也应恢复普通边框")
    }

    func testPaletteFooterButtonPaddingAcceptsClick() async throws {
        var historyClicks = 0
        var settingsClicks = 0
        let (window, host) = makeHostedWindow(
            size: NSSize(width: 260, height: 60),
            rootView: HStack(spacing: 12) {
                Button("执行历史") { historyClicks += 1 }
                Button("设置 ⌘,") { settingsClicks += 1 }
            }
            .buttonStyle(PaletteFooterButtonStyle())
            .padding(.leading, 20)
            .frame(width: 260, height: 60, alignment: .leading)
        )
        defer { teardownHostedWindow(window) }

        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            await nextLayout()
        }

        // 「执行历史」起点严格在 x = 20，左右留白各 8pt，高 24pt（垂直居中于 60 -> y ∈ [18, 42]）
        // 分别点中左侧 2pt 留白、底部 2pt 留白、顶部 2pt 留白
        for point in [NSPoint(x: 22, y: 30), NSPoint(x: 46, y: 20), NSPoint(x: 46, y: 40)] {
            let before = historyClicks
            try clickWindow(window, at: point)
            await nextLayout()
            XCTAssertEqual(historyClicks, before + 1, "「执行历史」留白点 \(point) 必须可点击触发")
        }

        // 测量「执行历史」宽度（文本宽 + 左右 16pt）+ 12pt 间距，定位第二个按钮「设置 ⌘,」起点
        let historyTextWidth = ceil(("执行历史" as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12)]).width)
        let settingsStartX = 20 + historyTextWidth + 16 + 12
        for point in [NSPoint(x: settingsStartX + 2, y: 30), NSPoint(x: settingsStartX + 26, y: 20), NSPoint(x: settingsStartX + 26, y: 40)] {
            let before = settingsClicks
            try clickWindow(window, at: point)
            await nextLayout()
            XCTAssertEqual(settingsClicks, before + 1, "「设置 ⌘,」留白点 \(point) 必须可点击触发")
        }

        // 同时验证真实 CommandPaletteView 底栏最右侧「设置 ⌘,」的右侧/底部留白可打开设置窗口
        SettingsWindowController.shared.window?.close()
        let tempSettingsURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("menu-bar-executor-footer-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempSettingsURL) }
        let tempSettings = AppSettingsManager(filePath: tempSettingsURL, enableFileMonitoring: false)
        let coordinator = PaletteCoordinator(settingsManager: tempSettings, runAutoCommand: { _, _ in {} })
        let (paletteWindow, paletteHost) = makeHostedWindow(
            size: NSSize(width: 600, height: 503),
            rootView: CommandPaletteView(coordinator: coordinator)
        )
        defer {
            teardownHostedWindow(paletteWindow)
            SettingsWindowController.shared.window?.close()
        }
        for _ in 0..<5 {
            paletteHost.layoutSubtreeIfNeeded()
            await nextLayout()
        }
        // 底栏高 43、右留白 12，按钮高 24 垂直居中（y ∈ [9.5, 33.5]），右缘在 x = 588 -> x = 585 落在右侧 8pt 留白内
        try clickWindow(paletteWindow, at: NSPoint(x: 585, y: 12))
        await nextLayout()
        XCTAssertEqual(SettingsWindowController.shared.window?.isVisible, true, "真实命令面板底栏「设置 ⌘,」右侧留白应能打开设置窗口")
    }

    func testCommandEditorTextFieldsAcceptEdgeClickAndShowFocusBorder() async throws {
        let command = Command(name: "", command: "printf test")
        let (window, host) = makeHostedWindow(
            size: NSSize(width: 620, height: 680),
            appearance: .aqua,
            rootView: CommandEditorView(command: command, onSave: { _ in true })
        )
        defer { teardownHostedWindow(window) }

        for _ in 0..<8 {
            host.layoutSubtreeIfNeeded()
            await nextLayout()
        }

        let content = try XCTUnwrap(window.contentView)
        for placeholder in ["例如：启动 Docker 服务", "默认工作目录"] {
            let field = try XCTUnwrap(descendants(content).compactMap { $0 as? NSTextField }.first {
                $0.placeholderString == placeholder
            }, "应找到输入框 \(placeholder)")
            let fieldRect = field.convert(field.bounds, to: nil)
            // 外框高 36pt、左右留白 10pt；探测外框左侧留白（fieldRect 左侧 6pt 处）与外框上下留白（fieldRect 中线偏上下 14pt 处）
            let boxMidY = fieldRect.midY
            let edgePoints = [
                NSPoint(x: fieldRect.minX - 6, y: boxMidY),
                NSPoint(x: fieldRect.midX, y: boxMidY + 14),
                NSPoint(x: fieldRect.midX, y: boxMidY - 14)
            ]
            for point in edgePoints {
                window.makeFirstResponder(nil)
                await nextLayout()
                XCTAssertFalse(try hasBlueTopBorder(around: field, in: content, halfHeight: 18), "「\(placeholder)」失焦后应恢复普通边框")
                try clickWindow(window, at: point, postUpFirst: true)
                await nextLayout()
                let editor = try XCTUnwrap(
                    field.currentEditor() as? NSTextView,
                    "点击「\(placeholder)」框内留白 \(point) 应聚焦输入框（文本区 \(fieldRect)）"
                )
                XCTAssertTrue(window.firstResponder === editor)
                XCTAssertTrue(try hasBlueTopBorder(around: field, in: content, halfHeight: 18), "「\(placeholder)」聚焦后应显示蓝色边框")
                editor.insertText("demo", replacementRange: editor.selectedRange())
                XCTAssertEqual(field.stringValue, "demo")
                editor.selectAll(nil)
                editor.deleteBackward(nil)
            }
        }

        // 分组输入框与工作目录输入框应保持同一视觉基线高度（同为 36pt 表单输入框）
        let groupField = try XCTUnwrap(descendants(content).compactMap { $0 as? NSTextField }.first {
            $0.placeholderString == "选择或输入分组"
        })
        let dirField = try XCTUnwrap(descendants(content).compactMap { $0 as? NSTextField }.first {
            $0.placeholderString == "默认工作目录"
        })
        let groupRect = groupField.convert(groupField.bounds, to: nil)
        let dirRect = dirField.convert(dirField.bounds, to: nil)
        XCTAssertEqual(groupRect.midY, dirRect.midY, accuracy: 2, "分组输入框应与右侧工作目录输入框保持同高齐平")
        let menuGeo = CommandGroupField.menuPopupGeometry(boxWidth: 224, buttonSize: NSSize(width: 28, height: 34))
        XCTAssertEqual(menuGeo.minimumWidth, 224, accuracy: 0.5, "下拉菜单宽度应与分组框一致")
        XCTAssertEqual(menuGeo.origin.x, -196, accuracy: 0.5, "下拉菜单左缘应与分组框左缘对齐")
        XCTAssertEqual(menuGeo.origin.y, 38, accuracy: 0.5, "下拉菜单应贴合分组框底边下方 4pt")

        // 处于中文组词态时，点击框内留白不得结束编辑或清空 markedText
        let nameField = try XCTUnwrap(descendants(content).compactMap { $0 as? NSTextField }.first {
            $0.placeholderString == "例如：启动 Docker 服务"
        })
        XCTAssertTrue(window.makeFirstResponder(nameField))
        await nextLayout()
        let composingEditor = try XCTUnwrap(nameField.currentEditor() as? NSTextView)
        composingEditor.setMarkedText(
            "zhongwen",
            selectedRange: NSRange(location: 8, length: 0),
            replacementRange: NSRange(location: 0, length: composingEditor.string.count)
        )
        XCTAssertTrue(composingEditor.hasMarkedText())
        let nameRect = nameField.convert(nameField.bounds, to: nil)
        let paddingPoint = NSPoint(x: nameRect.minX - 6, y: nameRect.midY)
        try clickWindow(window, at: paddingPoint, postUpFirst: true)
        await nextLayout()
        XCTAssertTrue(composingEditor.hasMarkedText(), "编辑框中文组词期间点击留白不得打断 markedText")
        XCTAssertEqual(composingEditor.string, "zhongwen")
    }

    func testCommandGroupFieldPreservesMarkedTextDuringSwiftUIUpdate() async throws {
        final class Model: ObservableObject {
            @Published var text = "开发"
            @Published var groups = ["开发"]
        }
        struct HostView: View {
            @ObservedObject var model: Model
            var body: some View {
                CommandGroupField(text: $model.text, groups: model.groups)
                    .frame(width: 220, height: 28)
            }
        }

        let model = Model()
        let (window, host) = makeHostedWindow(
            size: NSSize(width: 300, height: 80),
            rootView: HostView(model: model)
        )
        defer { teardownHostedWindow(window) }

        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            await nextLayout()
        }

        let groupField = try XCTUnwrap(descendants(host).compactMap { $0 as? NSTextField }.first {
            $0.accessibilityLabel() == "分组"
        })
        XCTAssertTrue(window.makeFirstResponder(groupField))
        await nextLayout()
        let editor = try XCTUnwrap(groupField.currentEditor() as? NSTextView)
        // 模拟中文输入法组词中：框内已有未提交的 markedText，绑定值仍为旧值 "开发"
        editor.setMarkedText("zhongwen", selectedRange: NSRange(location: 8, length: 0), replacementRange: NSRange(location: 0, length: editor.string.count))
        XCTAssertTrue(editor.hasMarkedText())

        // 触发 groups 更新，促使 SwiftUI 调用 CommandGroupField.updateNSView
        model.groups = ["开发", "工具"]
        await nextLayout()
        host.layoutSubtreeIfNeeded()

        XCTAssertTrue(editor.hasMarkedText(), "分组下拉框中文组词期间不得被 updateNSView 打断")
        XCTAssertEqual(editor.string, "zhongwen")
    }

    func testCommandEditorMultilineTextEditorProtectsMarkedTextShowsFocusBorderAndSupportsCommandReturn() async throws {
        final class Model: ObservableObject {
            @Published var text = "echo hi"
            var commandReturnCount = 0
        }
        struct HostView: View {
            @ObservedObject var model: Model
            var body: some View {
                InterfaceTextEditor(text: $model.text, height: 86) {
                    model.commandReturnCount += 1
                }
                .padding(16)
                .frame(width: 460, height: 120)
            }
        }

        let model = Model()
        let (window, host) = makeHostedWindow(
            size: NSSize(width: 460, height: 120),
            appearance: .aqua,
            rootView: HostView(model: model)
        )
        defer { teardownHostedWindow(window) }

        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            await nextLayout()
        }

        let content = try XCTUnwrap(window.contentView)
        let scrollView = try XCTUnwrap(descendants(content).compactMap { $0 as? NSScrollView }.first)
        let textView = try XCTUnwrap(scrollView.documentView as? CommandEditorTextView)

        XCTAssertFalse(textView.isAutomaticQuoteSubstitutionEnabled, "命令编辑器应关闭智能引号替换")
        XCTAssertFalse(textView.isAutomaticDashSubstitutionEnabled, "命令编辑器应关闭智能破折号替换")

        window.makeFirstResponder(nil)
        await nextLayout()
        XCTAssertFalse(try hasBlueTopBorder(around: scrollView, in: content, halfHeight: 43), "失焦时命令框应恢复普通边框")

        // 点击命令框底部留白应直接聚焦并展示蓝色焦点边框
        let scrollRect = scrollView.convert(scrollView.bounds, to: nil)
        try clickWindow(window, at: NSPoint(x: scrollRect.maxX - 18, y: scrollRect.minY + 10), postUpFirst: true)
        await nextLayout()
        XCTAssertTrue(window.firstResponder === textView, "点击命令框底部留白应聚焦命令编辑器")
        XCTAssertTrue(try hasBlueTopBorder(around: scrollView, in: content, halfHeight: 43), "聚焦时命令框应显示 1px 蓝色边框")

        // 中文组词期间，SwiftUI 更新不得覆写 markedText，且 ⌘↩ 不得误触发提交
        textView.setMarkedText("ceshi", selectedRange: NSRange(location: 5, length: 0), replacementRange: NSRange(location: 0, length: textView.string.count))
        XCTAssertTrue(textView.hasMarkedText())
        model.text = "echo external"
        await nextLayout()
        XCTAssertTrue(textView.hasMarkedText(), "命令编辑器中文组词期间不得被 updateNSView 打断")

        let cmdReturn = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.command],
            timestamp: 0, windowNumber: window.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: KeyCode.returnKey
        ))
        XCTAssertFalse(textView.performKeyEquivalent(with: cmdReturn), "中文组词期间 ⌘↩ 不应截获提交")
        XCTAssertEqual(model.commandReturnCount, 0)

        textView.unmarkText()
        XCTAssertTrue(textView.performKeyEquivalent(with: cmdReturn), "非组词态按 ⌘↩ 应触发保存回调")
        XCTAssertEqual(model.commandReturnCount, 1)

        // 焦点位于同一窗口的其他输入框且正在中文组词时，CommandEditorTextView 不得截获 ⌘↩
        let otherField = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        content.addSubview(otherField)
        defer { otherField.removeFromSuperview() }
        XCTAssertTrue(window.makeFirstResponder(otherField))
        await nextLayout()
        let otherEditor = try XCTUnwrap(otherField.currentEditor() as? NSTextView)
        otherEditor.setMarkedText("mingcheng", selectedRange: NSRange(location: 9, length: 0), replacementRange: NSRange(location: 0, length: otherEditor.string.count))
        XCTAssertTrue(otherEditor.hasMarkedText())
        XCTAssertFalse(textView.performKeyEquivalent(with: cmdReturn), "其他输入框中文组词期间 ⌘↩ 不得被多行命令框截获保存")
        XCTAssertEqual(model.commandReturnCount, 1)
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

    private func makeHostedWindow<Content: View>(
        size: NSSize,
        appearance: NSAppearance.Name? = nil,
        rootView: Content
    ) -> (NSWindow, NSHostingView<Content>) {
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: 120, y: 120), size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        if let appearance { window.appearance = NSAppearance(named: appearance) }
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: rootView)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        return (window, host)
    }

    private func teardownHostedWindow(_ window: NSWindow) {
        window.orderOut(nil)
        window.contentView = nil
    }

    private func clickWindow(_ window: NSWindow, at point: NSPoint, postUpFirst: Bool = false) throws {
        let down = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1
        ))
        let up = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseUp, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 2, clickCount: 1, pressure: 1
        ))
        if postUpFirst {
            NSApp.postEvent(up, atStart: true)
            window.sendEvent(down)
        } else {
            window.sendEvent(down)
            window.sendEvent(up)
        }
    }

    private func hasBlueTopBorder(around view: NSView, in content: NSView, halfHeight: CGFloat) throws -> Bool {
        content.layoutSubtreeIfNeeded()
        let bounds = content.bounds
        let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: bounds))
        content.cacheDisplay(in: bounds, to: bitmap)
        let viewBounds = view.convert(view.bounds, to: content)
        let scaleX = CGFloat(bitmap.pixelsWide) / bounds.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / bounds.height
        let x = Int(viewBounds.midX * scaleX)
        let centerY = content.isFlipped ? viewBounds.midY : bounds.maxY - viewBounds.midY
        let top = Int((centerY - halfHeight) * scaleY)
        return ((top - 2)...(top + 2)).contains { y in
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
            return color.blueComponent - color.redComponent > 0.35
        }
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
