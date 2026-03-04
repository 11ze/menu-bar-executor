import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {
        requestAuthorization()
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    func showSuccess(commandName: String) {
        let content = UNMutableNotificationContent()
        content.title = "命令执行成功"
        content.body = commandName
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showFailure(commandName: String, error: String) {
        let content = UNMutableNotificationContent()
        content.title = "命令执行失败"
        content.body = "\(commandName): \(error)"
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
        content.title = "配置已重载"
        content.body = "命令列表已更新"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
