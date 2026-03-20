import Foundation

/// 应用程序路径管理
enum AppPaths {
    /// 配置目录路径 (~/.config/menu-bar-executor/)
    static let configDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config")
        .appendingPathComponent("menu-bar-executor")

    /// 命令配置文件路径
    static var commandsFile: URL { configDirectory.appendingPathComponent("commands.json") }

    /// 全局设置文件路径
    static var settingsFile: URL { configDirectory.appendingPathComponent("settings.json") }

    /// 执行历史文件路径
    static var historyFile: URL { configDirectory.appendingPathComponent("history.json") }

    /// 确保配置目录存在
    static func ensureDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: configDirectory.path) {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }
    }
}
