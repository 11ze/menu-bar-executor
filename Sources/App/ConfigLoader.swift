import Foundation

final class ConfigLoader {
    static let shared = ConfigLoader()

    private let configFileName = "commands.json"
    private let configDirName = "menu-bar-executor"

    private init() {}

    var configDirectory: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".config").appendingPathComponent(configDirName)
    }

    var configFilePath: URL {
        configDirectory.appendingPathComponent(configFileName)
    }

    var defaultConfigPath: URL? {
        Bundle.main.url(forResource: "commands", withExtension: "json")
    }

    func loadConfig() -> [Command] {
        // 尝试加载用户配置
        if FileManager.default.fileExists(atPath: configFilePath.path) {
            do {
                let data = try Data(contentsOf: configFilePath)
                let config = try JSONDecoder().decode(CommandsConfig.self, from: data)
                return config.commands
            } catch {
                // 加载失败，回退到默认配置
            }
        }

        // 加载默认配置
        if let defaultPath = defaultConfigPath {
            do {
                let data = try Data(contentsOf: defaultPath)
                let config = try JSONDecoder().decode(CommandsConfig.self, from: data)
                return config.commands
            } catch {
                // 默认配置也加载失败
            }
        }

        return []
    }

    func ensureConfigDirectoryExists() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configDirectory.path) {
            do {
                try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
                // 复制默认配置（如果存在）
                if let defaultPath = defaultConfigPath {
                    let defaultData = try Data(contentsOf: defaultPath)
                    try defaultData.write(to: configFilePath)
                }
            } catch {
                // 目录创建或配置复制失败
            }
        }
    }

    func saveConfig(_ commands: [Command]) throws {
        ensureConfigDirectoryExists()

        let config = CommandsConfig(commands: commands)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        // 原子写入：先写入临时文件，再替换
        let tempPath = configFilePath.appendingPathExtension("tmp")
        try data.write(to: tempPath, options: .atomic)

        // 原子替换
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: configFilePath.path) {
            try fileManager.replaceItem(at: configFilePath, withItemAt: tempPath, backupItemName: nil, resultingItemURL: nil)
        } else {
            try fileManager.moveItem(at: tempPath, to: configFilePath)
        }
    }
}
