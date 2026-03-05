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
        print("[ConfigLoader] configFilePath: \(configFilePath.path)")
        print("[ConfigLoader] defaultConfigPath: \(defaultConfigPath?.path ?? "nil")")

        // 尝试加载用户配置
        if FileManager.default.fileExists(atPath: configFilePath.path) {
            print("[ConfigLoader] 找到用户配置文件")
            do {
                let data = try Data(contentsOf: configFilePath)
                let config = try JSONDecoder().decode(CommandsConfig.self, from: data)
                return config.commands
            } catch {
                print("Failed to load user config: \(error)")
            }
        } else {
            print("[ConfigLoader] 用户配置文件不存在")
        }

        // 加载默认配置
        if let defaultPath = defaultConfigPath {
            print("[ConfigLoader] 找到默认配置文件: \(defaultPath.path)")
            do {
                let data = try Data(contentsOf: defaultPath)
                let config = try JSONDecoder().decode(CommandsConfig.self, from: data)
                return config.commands
            } catch {
                print("Failed to load default config: \(error)")
            }
        } else {
            print("[ConfigLoader] 默认配置文件不存在")
        }

        return []
    }

    func ensureConfigDirectoryExists() {
        print("[ConfigLoader] ensureConfigDirectoryExists: \(configDirectory.path)")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configDirectory.path) {
            print("[ConfigLoader] 目录不存在，需要创建")
            do {
                try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
                print("[ConfigLoader] 目录已创建")
                // 复制默认配置（如果存在）
                if let defaultPath = defaultConfigPath {
                    print("[ConfigLoader] 复制默认配置到: \(configFilePath.path)")
                    let defaultData = try Data(contentsOf: defaultPath)
                    try defaultData.write(to: configFilePath)
                    print("[ConfigLoader] 复制完成")
                } else {
                    print("[ConfigLoader] 没有默认配置可复制")
                }
            } catch {
                print("Failed to create config directory: \(error)")
            }
        } else {
            print("[ConfigLoader] 目录已存在")
        }
    }

    func saveConfig(_ commands: [Command]) throws {
        print("[ConfigLoader] 开始保存配置")
        ensureConfigDirectoryExists()

        let config = CommandsConfig(commands: commands)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        try data.write(to: configFilePath)
        print("[ConfigLoader] 配置已保存到: \(configFilePath.path)")
    }
}
