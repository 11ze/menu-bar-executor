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
            if let image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Menu Bar Executor") {
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
        print("[AppDelegate] buildMenu 开始")
        guard let button = statusItem?.button else {
            print("[AppDelegate] button 为 nil")
            return
        }

        let menu = NSMenu()
        let manager = CommandsManager.shared

        print("[AppDelegate] commands 数量: \(manager.commands.count)")
        for command in manager.commands {
            let item = NSMenuItem(
                title: command.name,
                action: #selector(executeCommand(_:)),
                keyEquivalent: ""
            )
            item.representedObject = command
            item.target = self
            if let iconName = command.icon {
                item.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            }
            menu.addItem(item)
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
        print("[AppDelegate] 菜单已设置，菜单项数量: \(menu.items.count)")
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
}
