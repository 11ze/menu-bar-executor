import AppKit
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private static let appName = "MenuBarExecutor"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
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

    func showSuccess(commandName: String, output: String?) {
        let content = UNMutableNotificationContent()
        content.title = Self.appName
        content.subtitle = "\(commandName)"

        if let output = output?.truncated(to: 100), !output.isEmpty {
            content.body = "✅\n\(output)"
        }

        content.sound = .default
        postNotification(content)
    }

    func showFailure(commandName: String, error: String, output: String?) {
        let content = UNMutableNotificationContent()
        content.title = Self.appName
        content.subtitle = "\(commandName)"

        var body = "❌\n\(error)"
        if let output = output?.truncated(to: 100), !output.isEmpty {
            body += "\n\(output)"
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
