import Foundation

final class ConfigLoader {
    static let shared = ConfigLoader()

    private init() {}

    var configDirectory: URL { AppPaths.configDirectory }
    var configFilePath: URL { AppPaths.commandsFile }

    var defaultConfigPath: URL? {
        Bundle.main.url(forResource: "commands", withExtension: "json")
    }

    func loadConfig() -> [Command] {
        // 尝试加载用户配置
        if FileManager.default.fileExists(atPath: configFilePath.path) {
            do {
                let data = try Data(contentsOf: configFilePath)
                let config = try JSONDecoder().decode(CommandsConfig.self, from: data)
                let commands = config.commands

                // 保存配置以补全缺失的 id 并标准化格式
                try? saveConfig(commands)

                return commands
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
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        // 检查是否是软链接
        let fileManager = FileManager.default
        let targetPath: URL
        do {
            let resolvedPath = try fileManager.destinationOfSymbolicLink(atPath: configFilePath.path)
            targetPath = URL(fileURLWithPath: resolvedPath)
        } catch {
            // 不是软链接，使用原路径
            targetPath = configFilePath
        }

        // 原子写入：先写入临时文件，再替换
        let tempPath = targetPath.appendingPathExtension("tmp")
        try data.write(to: tempPath, options: .atomic)

        // 原子替换目标文件
        if fileManager.fileExists(atPath: targetPath.path) {
            try fileManager.replaceItem(at: targetPath, withItemAt: tempPath, backupItemName: nil, resultingItemURL: nil)
        } else {
            try fileManager.moveItem(at: tempPath, to: targetPath)
        }
    }

    /// 导出配置到指定位置
    func exportConfig(to url: URL) throws {
        let data = try Data(contentsOf: configFilePath)
        try data.write(to: url)
    }

    /// 从指定位置导入配置
    func importConfig(from url: URL) throws -> [Command] {
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(CommandsConfig.self, from: data)
        return config.commands
    }
}
