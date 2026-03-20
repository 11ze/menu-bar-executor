import Foundation
import CoreGraphics

/// 全局设置（独立于 commands.json）
struct AppSettings: Codable {
    var palettePosition: CGPoint?   // 面板位置（单位：屏幕坐标，左下角为原点）
    var paletteSize: NSSize?        // 面板尺寸
    var defaultInputSourceID: String?  // 默认输入法 ID（打开面板时自动切换）
}

@MainActor
final class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()

    @Published var settings: AppSettings = AppSettings()

    private let filePath: URL

    private init() {
        filePath = AppPaths.settingsFile
        load()
    }

    func load() {
        do {
            let data = try Data(contentsOf: filePath)
            settings = try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            // 加载失败使用默认值（文件不存在或解析失败）
        }
    }

    func save() {
        do {
            try AppPaths.ensureDirectoryExists()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            let tempPath = filePath.appendingPathExtension("tmp")
            try data.write(to: tempPath, options: .atomic)
            try FileManager.default.replaceItem(at: filePath, withItemAt: tempPath, backupItemName: nil, resultingItemURL: nil)
        } catch {
            // 保存失败静默忽略
        }
    }

    /// 更新面板窗口帧（位置和尺寸）
    func updateWindowFrame(origin: CGPoint?, size: NSSize?) {
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
}
