import Foundation

struct Command: Identifiable, Codable {
    internal(set) var id: UUID
    var name: String
    let command: String
    var workingDirectory: String?
    var notification: Bool

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String? = nil,
        notification: Bool = true
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.notification = notification
    }

    enum CodingKeys: String, CodingKey {
        case id, name, command, workingDirectory, notification
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let uuid = try? container.decode(UUID.self, forKey: .id) {
            id = uuid
        } else {
            id = UUID()
        }

        name = try container.decode(String.self, forKey: .name)
        command = try container.decode(String.self, forKey: .command)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        notification = try container.decodeIfPresent(Bool.self, forKey: .notification) ?? true
    }
}
