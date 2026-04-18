import AppKit
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private static let appName = "MenuBarExecutor"

    /// 更新通知的标识符
    private static let updateNotificationIdentifier = "com.cai.menu-bar-executor.update"

    /// 更新通知点击后的回调
    private var updateActionHandler: (() -> Void)?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
        registerUpdateNotificationCategory()
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            Task { @MainActor in
                if let error = error {
                    self?.showErrorAlert("通知授权请求失败: \(error.localizedDescription)")
                } else if !granted {
                    self?.showPermissionAlert()
                }
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            if response.notification.request.content.categoryIdentifier == Self.updateNotificationIdentifier {
                updateActionHandler?()
                updateActionHandler = nil
            }
        }
        completionHandler()
    }

    func showSuccess(commandName: String, output: String?) {
        let content = UNMutableNotificationContent()
        content.title = Self.appName
        content.subtitle = "命令: \(commandName)"

        // output 去掉首尾空白
        let output = output?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let output = output?.truncated(to: 100), !output.isEmpty {
            content.body = "输出: \(output)"
        }

        content.sound = .default
        postNotification(content)
    }

    func showFailure(commandName: String, error: String, output: String?) {
        let content = UNMutableNotificationContent()
        content.title = Self.appName
        content.subtitle = "命令: \(commandName)"

        // error 去掉首尾空白
        let error = error.trimmingCharacters(in: .whitespacesAndNewlines)
        // output 去掉首尾空白
        let output = output?.trimmingCharacters(in: .whitespacesAndNewlines)

        var body = "错误: \(error)"
        if let output = output?.truncated(to: 100), !output.isEmpty {
            body += "\n输出: \(output)"
        }

        content.body = body
        content.sound = .default
        postNotification(content)
    }

    func showReloadSuccess() {
        let content = UNMutableNotificationContent()
        content.title = Self.appName
        content.body = "配置已重载: 命令列表已更新"
        content.sound = .default
        postNotification(content)
    }

    func showConfigLoadError(_ error: Error) {
        let content = UNMutableNotificationContent()
        content.title = Self.appName
        content.body = "配置加载失败: \(error.localizedDescription)"
        content.sound = .default
        postNotification(content)
    }

    /// 显示更新可用通知
    /// - Parameters:
    ///   - version: 最新版本号
    ///   - action: 点击通知后的回调
    func showUpdateAvailable(version: String, action: @escaping () -> Void) {
        updateActionHandler = action

        let content = UNMutableNotificationContent()
        content.title = Self.appName
        content.body = "发现新版本 \(version)，点击下载"
        content.sound = .default
        content.categoryIdentifier = Self.updateNotificationIdentifier

        let request = UNNotificationRequest(
            identifier: Self.updateNotificationIdentifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// 注册更新通知类别
    private func registerUpdateNotificationCategory() {
        let category = UNNotificationCategory(
            identifier: Self.updateNotificationIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func postNotification(_ content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.showErrorAlert("通知发送失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "通知权限未授权"
        alert.informativeText = "请在「系统设置 > 通知」中允许 MenuBarExecutor 发送通知。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "忽略")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "通知错误"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
