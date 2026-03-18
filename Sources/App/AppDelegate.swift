import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

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
