import AppKit
import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let commandPalette = Self("commandPalette")
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    /// 延迟显示辅助功能权限提示的秒数
    private let accessibilityPromptDelay: TimeInterval = 2.0
    /// UserDefaults key：是否已提示过辅助功能权限
    private let hasShownAccessibilityPromptKey = "hasShownAccessibilityPrompt"

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

        // 同步自启动状态
        LaunchAtLoginManager.shared.sync(withSettings: AppSettingsManager.shared.settings.launchAtLogin)

        // 注册全局快捷键（呼出命令面板）
        KeyboardShortcuts.onKeyUp(for: .commandPalette) {
            CommandPaletteWindowController.shared.show()
        }

        // 静默检查辅助功能权限
        let hasPermission = AXIsProcessTrusted()
        let hasShownPrompt = UserDefaults.standard.bool(forKey: hasShownAccessibilityPromptKey)

        // 仅首次未授权时提示，避免每次启动都打断用户
        guard !hasPermission, !hasShownPrompt else {
            // 自动检查更新
            UpdateManager.shared.performAutoCheck()
            return
        }

        UserDefaults.standard.set(true, forKey: hasShownAccessibilityPromptKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + accessibilityPromptDelay) {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "全局快捷键需要「系统设置 → 隐私与安全性 → 辅助功能」中授权本应用。\n\n授权后快捷键才能正常工作。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后提醒")
            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }

            // 自动检查更新
            UpdateManager.shared.performAutoCheck()
        }
    }

    private func buildMenu() {
        guard let button = statusItem?.button else { return }

        let menu = NSMenu()

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

        let checkUpdateItem = NSMenuItem(
            title: "检查更新...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        checkUpdateItem.target = self
        menu.addItem(checkUpdateItem)

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

    @objc private func reloadConfig() {
        Task { @MainActor in
            AppSettingsManager.shared.reload()
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

    @objc private func checkForUpdates() {
        Task {
            let updateManager = UpdateManager.shared
            let updateInfo = await updateManager.checkForUpdate(force: true)

            if let info = updateInfo {
                // 有新版本
                let alert = NSAlert()
                alert.messageText = "发现新版本 \(info.latestVersion)"
                alert.informativeText = "当前版本: \(info.currentVersion)\n\n\(info.releaseNotes ?? "点击下载查看更新内容")"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "下载")
                alert.addButton(withTitle: "跳过此版本")
                alert.addButton(withTitle: "取消")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    updateManager.openReleasePage()
                } else if response == .alertSecondButtonReturn {
                    updateManager.skipVersion(info.latestVersion)
                }
            } else if let error = updateManager.lastError {
                // 检查失败
                let alert = NSAlert()
                alert.messageText = "检查更新失败"
                alert.informativeText = error.errorDescription ?? "未知错误"
                alert.alertStyle = .warning

                // 针对 API 限流提供直接访问 GitHub 的选项
                if case .apiRateLimited = error {
                    alert.addButton(withTitle: "访问 GitHub")
                    alert.addButton(withTitle: "取消")
                    if alert.runModal() == .alertFirstButtonReturn {
                        updateManager.openReleasePage()
                    }
                } else {
                    alert.addButton(withTitle: "重试")
                    alert.addButton(withTitle: "取消")
                    if alert.runModal() == .alertFirstButtonReturn {
                        checkForUpdates()
                    }
                }
            } else {
                // 已是最新版本
                let alert = NSAlert()
                alert.messageText = "已是最新版本"
                alert.informativeText = "当前版本: \(updateManager.getCurrentVersion())"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "确定")
                alert.runModal()
            }
        }
    }
}
