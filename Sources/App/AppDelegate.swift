import AppKit
import SwiftUI
import Combine
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let commandPalette = Self("commandPalette")
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    /// 延迟显示辅助功能权限提示的秒数
    private let accessibilityPromptDelay: TimeInterval = 2.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "MenuBarExecutor") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "菜单"
            }
            button.toolTip = "菜单栏命令执行器"
        }

        buildMenu()

        Task { @MainActor in
            CommandsManager.shared.$commands
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.buildMenu()
                }
                .store(in: &cancellables)
        }

        // 注册全局快捷键（呼出命令面板）
        KeyboardShortcuts.onKeyUp(for: .commandPalette) { [self] in
            CommandPaletteWindowController.shared.show()
        }

        // 权限检测引导
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            // 延迟提示，避免启动时弹窗干扰
            DispatchQueue.main.asyncAfter(deadline: .now() + accessibilityPromptDelay) {
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = "全局快捷键需要「系统偏好设置 → 隐私与安全性 → 辅助功能」中授权本应用。授权后快捷键才能正常工作。"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "稍后")
                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    private func buildMenu() {
        guard let button = statusItem?.button else { return }

        let menu = NSMenu()
        let manager = CommandsManager.shared

        for command in manager.commands {
            menu.addItem(createMenuItem(for: command))
        }

        menu.addItem(NSMenuItem.separator())

        let reloadItem = NSMenuItem(
            title: "重载配置",
            action: #selector(reloadConfig),
            keyEquivalent: "r"
        )
        reloadItem.target = self
        reloadItem.keyEquivalentModifierMask = [.command]
        menu.addItem(reloadItem)

        let settingsItem = NSMenuItem(
            title: "命令设置...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let historyItem = NSMenuItem(
            title: "执行历史...",
            action: #selector(openHistory),
            keyEquivalent: "h"
        )
        historyItem.target = self
        historyItem.keyEquivalentModifierMask = [.command]
        menu.addItem(historyItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        button.menu = menu
        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func createMenuItem(for command: Command) -> NSMenuItem {
        let item = NSMenuItem(
            title: command.name,
            action: #selector(executeCommand(_:)),
            keyEquivalent: ""
        )
        item.representedObject = command
        item.target = self
        return item
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        // 左键点击：呼出命令面板
        // 右键点击：显示原有菜单
        guard let event = NSApp.currentEvent else { return }
        if event.type == .leftMouseUp {
            CommandPaletteWindowController.shared.show()
        } else if event.type == .rightMouseUp {
            guard let menu = sender.menu else { return }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
        }
    }

    @objc private func executeCommand(_ sender: NSMenuItem) {
        guard let command = sender.representedObject as? Command else { return }

        Task { @MainActor in
            CommandsManager.shared.execute(command)
        }
    }

    @objc private func reloadConfig() {
        Task { @MainActor in
            CommandsManager.shared.reload()
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func openHistory() {
        HistoryWindowController.shared.showWindow()
    }
}
