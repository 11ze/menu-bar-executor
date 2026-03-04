import Foundation

struct Command: Identifiable, Codable {
    let id: String
    let name: String
    let command: String
    var workingDirectory: String?
    var icon: String?
    var notification: Bool

    init(id: String, name: String, command: String, workingDirectory: String? = nil, icon: String? = nil, notification: Bool = true) {
        self.id = id
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
