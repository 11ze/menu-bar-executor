import Foundation

struct Command: Identifiable, Codable {
    var id: String { name }
    let name: String
    let command: String
    var workingDirectory: String?
    var icon: String?
    var notification: Bool

    init(name: String, command: String, workingDirectory: String? = nil, icon: String? = nil, notification: Bool = true) {
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.icon = icon
        self.notification = notification
    }
}

struct CommandsConfig: Codable {
    let commands: [Command]
}
