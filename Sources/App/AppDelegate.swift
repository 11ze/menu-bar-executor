import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Menu Bar Executor")
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
        Task { @MainActor in
            let manager = CommandsManager.shared

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

            menu.addItem(NSMenuItem.separator())

            let quitItem = NSMenuItem(
                title: "退出",
                action: #selector(quitApp),
                keyEquivalent: "q"
            )
            quitItem.target = self
            menu.addItem(quitItem)

            button.menu = menu
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
}
