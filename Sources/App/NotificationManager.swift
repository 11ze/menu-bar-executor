import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

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
        content.title = "Menu Bar Executor"
        content.subtitle = "✅ \(commandName)"

        if let output = output?.truncated(to: 100), !output.isEmpty {
            content.body = "输出：\n\(output)"
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showFailure(commandName: String, error: String, output: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Menu Bar Executor"
        content.subtitle = "❌ \(commandName)"

        var body = "错误：\n\(error)"
        if let output = output?.truncated(to: 100), !output.isEmpty {
            body += "\n\n输出：\n\(output)"
        }

        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showReloadSuccess() {
        let content = UNMutableNotificationContent()
        content.title = "Menu Bar Executor"
        content.body = "配置已重载: 命令列表已更新"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
