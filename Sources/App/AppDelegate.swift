import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "MenuBarExecutor") {
                image.isTemplate = true
                button.image = image
            } else {
                // 如果图标加载失败，使用文本标题
                button.title = "菜单"
            }
            button.toolTip = "菜单栏命令执行器"
        }

        // 构建菜单
        buildMenu()

        // 监听命令列表变化
        Task { @MainActor in
            CommandsManager.shared.$commands
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.buildMenu()
                }
                .store(in: &cancellables)
        }
    }

    private func buildMenu() {
        guard let button = statusItem?.button else { return }

        let menu = NSMenu()
        let manager = CommandsManager.shared

        // 按分组组织命令
        let groupedCommands = Dictionary(grouping: manager.commands) { $0.group }
        let sortedGroups = groupedCommands.keys.sorted { ($0 ?? "") < ($1 ?? "") }

        for group in sortedGroups {
            guard let commands = groupedCommands[group] else { continue }

            if let group = group, !group.isEmpty {
                // 有分组：创建子菜单
                let submenu = NSMenu()
                for command in commands {
                    submenu.addItem(createMenuItem(for: command))
                }

                let submenuItem = NSMenuItem(title: group, action: nil, keyEquivalent: "")
                submenuItem.submenu = submenu
                menu.addItem(submenuItem)
            } else {
                // 无分组：直接添加到顶层
                for command in commands {
                    menu.addItem(createMenuItem(for: command))
                }
            }
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
            keyEquivalent: command.shortcut ?? ""
        )
        item.representedObject = command
        item.target = self
        if let iconName = command.icon {
            item.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        }
        return item
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let menu = sender.menu else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
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
