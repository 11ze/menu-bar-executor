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

    func showSuccess(commandName: String, output: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Menu Bar Executor"

        // 显示命令名称和执行结果（如果有输出）
        if let output = output, !output.isEmpty {
            // 限制输出长度，避免通知内容过长
            let truncatedOutput = output.count > 100 ? String(output.prefix(100)) + "..." : output
            content.body = "command: \(commandName)\noutput: \(truncatedOutput)"
        } else {
            content.body = "command: \(commandName)"
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

        // 显示命令名称、错误信息和执行结果（如果有）
        var body = "command: \(commandName)\noutput: \(error)"
        if let output = output, !output.isEmpty {
            let truncatedOutput = output.count > 100 ? String(output.prefix(100)) + "..." : output
            body += "\noutput: \(truncatedOutput)"
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
