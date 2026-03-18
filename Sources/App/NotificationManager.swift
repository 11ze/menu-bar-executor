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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
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
        content.subtitle = "✅ \(commandName)"

        if let output = output?.truncated(to: 100), !output.isEmpty {
            content.body = "输出：\n\(output)"
        }

        content.sound = .default
        postNotification(content)
    }

    func showFailure(commandName: String, error: String, output: String?) {
        let content = UNMutableNotificationContent()
        content.title = Self.appName
        content.subtitle = "❌ \(commandName)"

        var body = "错误：\n\(error)"
        if let output = output?.truncated(to: 100), !output.isEmpty {
            body += "\n\n输出：\n\(output)"
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
        UNUserNotificationCenter.current().add(request)
    }
}
