import Foundation
import CoreGraphics
import Combine

// MARK: - 辅助结构体（对象格式的 CGPoint 和 NSSize）

/// 用于 JSON 编解码的 CGPoint 表示（对象格式）
private struct CGPointObject: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat

    init(from point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

/// 用于 JSON 编解码的 NSSize 表示（对象格式）
private struct NSSizeObject: Codable, Equatable {
    var width: CGFloat
    var height: CGFloat

    init(from size: NSSize) {
        self.width = size.width
        self.height = size.height
    }

    var nsSize: NSSize { NSSize(width: width, height: height) }
}

// MARK: - 统一配置结构

/// 统一配置结构
struct AppSettings: Codable {
    var commands: [Command] = []
    var palettePosition: CGPoint?
    var paletteSize: NSSize?
    var defaultInputSourceID: String?
    var launchAtLogin: Bool = false

    /// 上次检查更新时间
    var lastUpdateCheckDate: Date?

    /// 用户跳过的版本号
    var skippedVersion: String?

    enum CodingKeys: String, CodingKey {
        case commands
        case palettePosition
        case paletteSize
        case defaultInputSourceID
        case launchAtLogin
        case lastUpdateCheckDate
        case skippedVersion
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commands = try container.decodeIfPresent([Command].self, forKey: .commands) ?? []
        defaultInputSourceID = try container.decodeIfPresent(String.self, forKey: .defaultInputSourceID)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        lastUpdateCheckDate = try container.decodeIfPresent(Date.self, forKey: .lastUpdateCheckDate)
        skippedVersion = try container.decodeIfPresent(String.self, forKey: .skippedVersion)

        if let posObj = try container.decodeIfPresent(CGPointObject.self, forKey: .palettePosition) {
            palettePosition = posObj.cgPoint
        }
        if let sizeObj = try container.decodeIfPresent(NSSizeObject.self, forKey: .paletteSize) {
            paletteSize = sizeObj.nsSize
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commands, forKey: .commands)
        try container.encodeIfPresent(defaultInputSourceID, forKey: .defaultInputSourceID)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encodeIfPresent(lastUpdateCheckDate, forKey: .lastUpdateCheckDate)
        try container.encodeIfPresent(skippedVersion, forKey: .skippedVersion)

        if let pos = palettePosition {
            try container.encode(CGPointObject(from: pos), forKey: .palettePosition)
        }
        if let size = paletteSize {
            try container.encode(NSSizeObject(from: size), forKey: .paletteSize)
        }
    }
}

/// 配置重载通知
extension Notification.Name {
    static let settingsDidReload = Notification.Name("settingsDidReload")
}

// MARK: - 配置管理器

@MainActor
final class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()

    @Published var settings: AppSettings = AppSettings()

    private let filePath: URL
    private let resolvedFilePath: URL
    private let notificationManager = NotificationManager.shared

    private init() {
        filePath = AppPaths.settingsFile
        // 初始化时一次性解析软链接
        if let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: filePath.path) {
            resolvedFilePath = URL(fileURLWithPath: resolved)
        } else {
            resolvedFilePath = filePath
        }
        load()
    }

    // MARK: - 加载

    func load() {
        guard FileManager.default.fileExists(atPath: filePath.path) else { return }
        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            settings = try decoder.decode(AppSettings.self, from: data)
            if fixDuplicateCommandIds() {
                save()
            }
        } catch {
            // 加载失败使用默认值
        }
    }

    // MARK: - 保存

    func save() {
        do {
            try AppPaths.ensureDirectoryExists()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(settings)

            // 原子写入
            let fileManager = FileManager.default
            let tempPath = resolvedFilePath.appendingPathExtension("tmp")
            try data.write(to: tempPath, options: .atomic)

            if fileManager.fileExists(atPath: resolvedFilePath.path) {
                try fileManager.replaceItem(at: resolvedFilePath, withItemAt: tempPath, backupItemName: nil, resultingItemURL: nil)
            } else {
                try fileManager.moveItem(at: tempPath, to: resolvedFilePath)
            }
        } catch {
            // 保存失败静默忽略
        }
    }

    /// 修复重复的命令 ID，返回是否有修复
    private func fixDuplicateCommandIds() -> Bool {
        var seenIds = Set<UUID>()
        var hasDuplicates = false

        for i in settings.commands.indices {
            let id = settings.commands[i].id
            if seenIds.contains(id) {
                settings.commands[i].id = UUID()
                seenIds.insert(settings.commands[i].id)
                hasDuplicates = true
            } else {
                seenIds.insert(id)
            }
        }

        return hasDuplicates
    }

    /// 更新面板帧（位置和尺寸）
    func updatePaletteFrame(origin: CGPoint?, size: NSSize?) {
        var changed = false
        if let origin = origin, settings.palettePosition != origin {
            settings.palettePosition = origin
            changed = true
        }
        if let size = size, settings.paletteSize != size {
            settings.paletteSize = size
            changed = true
        }
        if changed {
            save()
        }
    }

    // MARK: - 命令管理

    func saveCommands(_ commands: [Command]) throws {
        settings.commands = commands
        save()
    }

    // MARK: - 重载

    func reload() {
        load()
        notificationManager.showReloadSuccess()
        NotificationCenter.default.post(name: .settingsDidReload, object: nil)
    }

    // MARK: - 导入导出

    func exportSettings(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(settings)
        try data.write(to: url)
    }

    func importSettings(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        settings = try decoder.decode(AppSettings.self, from: data)
        _ = fixDuplicateCommandIds()
        save()
    }
}
