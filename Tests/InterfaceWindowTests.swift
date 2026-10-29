import AppKit
import SwiftUI
import XCTest
@testable import MenuBarExecutor

@MainActor
final class InterfaceWindowTests: XCTestCase {
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
            for width in [360, 560, 800] {
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
        let close = descendants(content).compactMap { $0 as? NSButton }.first {
            $0.accessibilitySubrole() == .closeButton
        }
        XCTAssertNotNil(close, "标题区应使用能关闭真实窗口的系统按钮")
        close?.performClick(nil)
        XCTAssertFalse(window.isVisible)
    }

    func testHistoryWindowUsesOneTitlebarAfterReopening() async throws {
        let controller = HistoryWindowController.shared
        controller.showWindow()
        let window = try XCTUnwrap(NSApp.windows.first { $0.title == "执行历史" })
        window.performClose(nil)
        controller.showWindow()
        await nextLayout()
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(try XCTUnwrap(window.contentView).bounds.height, window.frame.height, accuracy: 1,
                       "重新打开历史窗口仍应采用原型内置标题区")
        window.performClose(nil)
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
        })
        coordinator.autoExecuteResults[fixture.commands[0].id] = .success("192.168.31.108")
        coordinator.autoExecuteResults[fixture.commands[1].id] = .success("main")
        let sample = Command(name: "启动 Docker 服务", command: "open -a Docker", group: "开发工具", directExecution: true)
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let suffix = appearance == .aqua ? "light" : "dark"
            for (label, size) in [
                ("normal", NSSize(width: 840, height: 549)),
                ("narrow", NSSize(width: 640, height: 549)),
                ("short", NSSize(width: 840, height: 420)),
                ("minimum", NSSize(width: 640, height: 420))
            ] {
                try await snapshot(SettingsView(), size: size, name: "commands-\(suffix)-\(label)", folder: folder, appearance: appearance)
                try await snapshot(VStack(spacing: 0) { WindowHeader(title: "设置"); GeneralSettingsView() }, size: size,
                                   name: "general-\(suffix)-\(label)", folder: folder, appearance: appearance)
                try await snapshot(HistoryView(), size: NSSize(width: size.width, height: size.height == 549 ? 566 : 420),
                                   name: "history-\(suffix)-\(label)", folder: folder, appearance: appearance)
            }
            try await snapshot(CommandPaletteView(coordinator: coordinator), size: NSSize(width: 560, height: 508),
                               name: "palette-\(suffix)", folder: folder, appearance: appearance)
            try await snapshot(CommandEditorView(command: sample, onSave: { _ in }, onDelete: {}),
                               size: NSSize(width: 560, height: 680), name: "editor-\(suffix)", folder: folder, appearance: appearance)
            try await snapshot(VStack(spacing: 0) {
                CommandPaletteRow(command: sample, displayIndex: 1, isSelected: true, searchText: "", autoExecuteState: .success("192.168.31.108"))
                CommandPaletteRow(command: sample, displayIndex: 2, isSelected: false, searchText: "", autoExecuteState: .loading)
                CommandPaletteRow(command: sample, displayIndex: 3, isSelected: false, searchText: "", autoExecuteState: .failure("执行失败"))
                CommandPaletteRow(command: sample, displayIndex: 4, isSelected: false, searchText: "", autoExecuteState: .success(""))
            }.padding(8).background(InterfaceStyle.surface), size: NSSize(width: 560, height: 160),
            name: "palette-results-\(suffix)", folder: folder, appearance: appearance)
        }
        print("Native interface snapshots: \(folder.path)")
    }

    private func snapshot<Content: View>(_ content: Content, size: NSSize, name: String, folder: URL, appearance: NSAppearance.Name) async throws {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: content)
        window.contentView = host
        window.setContentSize(size)
        window.orderFront(nil)
        await nextLayout()
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(data.count, 1000, "不能把空图片当作界面渲染成功")
        try data.write(to: folder.appendingPathComponent(name + ".png"))
        window.orderOut(nil)
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
