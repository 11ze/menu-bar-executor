import Foundation

struct Command: Identifiable, Codable {
    let id: UUID
    var name: String
    let command: String
    var workingDirectory: String?
    var icon: String?
    var notification: Bool

    // Phase 3 预留字段
    var group: String?
    var shortcut: String?

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String? = nil,
        icon: String? = nil,
        notification: Bool = true,
        group: String? = nil,
        shortcut: String? = nil
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.icon = icon
        self.notification = notification
        self.group = group
        self.shortcut = shortcut
    }

    /// 用于 JSON 解码的键，支持旧版配置文件兼容
    enum CodingKeys: String, CodingKey {
        case id, name, command, workingDirectory, icon, notification, group, shortcut
    }

    /// 从旧版配置解码时，如果没有 id 字段则自动生成
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 兼容旧配置：id 可能不存在，自动生成 UUID
        if let uuid = try? container.decode(UUID.self, forKey: .id) {
            id = uuid
        } else {
            id = UUID()
        }

        name = try container.decode(String.self, forKey: .name)
        command = try container.decode(String.self, forKey: .command)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        notification = try container.decodeIfPresent(Bool.self, forKey: .notification) ?? true
        group = try container.decodeIfPresent(String.self, forKey: .group)
        shortcut = try container.decodeIfPresent(String.self, forKey: .shortcut)
    }
}

struct CommandsConfig: Codable {
    var commands: [Command]
}
