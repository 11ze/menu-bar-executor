import Foundation

final class ConfigLoader {
    static let shared = ConfigLoader()

    private let configFileName = "commands.json"
    private let configDirName = "menu-bar-exector"

    private init() {}

    var configDirectory: URL {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".config").appendingPathComponent(configDirName)
    }

    var configFilePath: URL {
        configDirectory.appendingPathComponent(configFileName)
    }

    var defaultConfigPath: URL {
        Bundle.main.url(forResource: "commands", withExtension: "json")!
    }

    func loadConfig() -> [Command] {
        // 尝试加载用户配置
        if FileManager.default.fileExists(atPath: configFilePath.path) {
            do {
                let data = try Data(contentsOf: configFilePath)
                let config = try JSONDecoder().decode(CommandsConfig.self, from: data)
                return config.commands
            } catch {
                print("Failed to load user config: \(error)")
            }
        }

        // 加载默认配置
        do {
            let data = try Data(contentsOf: defaultConfigPath)
            let config = try JSONDecoder().decode(CommandsConfig.self, from: data)
            return config.commands
        } catch {
            print("Failed to load default config: \(error)")
        }

        return []
    }

    func ensureConfigDirectoryExists() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: configDirectory.path) {
            do {
                try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
                // 复制默认配置
                let defaultData = try Data(contentsOf: defaultConfigPath)
                try defaultData.write(to: configFilePath)
            } catch {
                print("Failed to create config directory: \(error)")
            }
        }
    }
}
