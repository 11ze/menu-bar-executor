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
struct AppSettings: Codable, Equatable {
    var commands: [Command] = []
    var palettePosition: CGPoint?
    var paletteSize: NSSize?
    var defaultInputSourceID: String?
    var launchAtLogin: Bool = false

    /// 上次检查更新时间
    var lastUpdateCheckDate: Date?

    /// 用户跳过的版本号
    var skippedVersion: String?

    /// 分组显示顺序（nil 时按命令列表中首次出现顺序）
    var groupOrder: [String]?

    enum CodingKeys: String, CodingKey {
        case commands
        case palettePosition
        case paletteSize
        case defaultInputSourceID
        case launchAtLogin
        case lastUpdateCheckDate
        case skippedVersion
        case groupOrder
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commands = try container.decodeIfPresent([Command].self, forKey: .commands) ?? []
        defaultInputSourceID = try container.decodeIfPresent(String.self, forKey: .defaultInputSourceID)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        lastUpdateCheckDate = try container.decodeIfPresent(Date.self, forKey: .lastUpdateCheckDate)
        skippedVersion = try container.decodeIfPresent(String.self, forKey: .skippedVersion)
        groupOrder = try container.decodeIfPresent([String].self, forKey: .groupOrder)

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
        try container.encodeIfPresent(groupOrder, forKey: .groupOrder)

        if let pos = palettePosition {
            try container.encode(CGPointObject(from: pos), forKey: .palettePosition)
        }
        if let size = paletteSize {
            try container.encode(NSSizeObject(from: size), forKey: .paletteSize)
        }
    }
}

// MARK: - 配置迁移

extension AppSettings {

    /// 迁移单入口：旧格式（echo 分隔符假分组）转 group 字段 + 修复重复命令 ID。
    /// 返回是否发生了改动，调用方据此决定是否写盘。
    @discardableResult
    static func migrateIfNeeded(_ settings: inout AppSettings) -> Bool {
        let migrated = migrateFakeGroupCommands(&settings)
        let fixed = fixDuplicateCommandIds(&settings)
        return migrated || fixed
    }

    /// 检测假命令（echo 分隔符）并迁移为 group 字段，返回是否发生了迁移
    private static func migrateFakeGroupCommands(_ settings: inout AppSettings) -> Bool {
        var commands = settings.commands
        var migrated = false
        var currentGroup: String?
        var indicesToRemove: IndexSet = []

        for i in commands.indices {
            let cmd = commands[i]
            let trimmedName = cmd.name.trimmingCharacters(in: .whitespaces)

            if !cmd.notification
                && cmd.command.trimmingCharacters(in: .whitespaces).hasPrefix("echo")
                && isSeparatorCommand(cmd.command)
                && !trimmedName.isEmpty
                && trimmedName.count < 30 {
                currentGroup = trimmedName
                indicesToRemove.insert(i)
                migrated = true
            } else if let group = currentGroup, commands[i].group == nil {
                commands[i].group = group
            }
        }

        if migrated {
            for index in indicesToRemove.reversed() {
                commands.remove(at: index)
            }
            settings.commands = commands

            // 迁移后建立 groupOrder
            var seen = Set<String>()
            var order: [String] = []
            for cmd in commands {
                if let g = cmd.group, seen.insert(g).inserted {
                    order.append(g)
                }
            }
            if !order.isEmpty {
                settings.groupOrder = order
            }
        }

        return migrated
    }

    /// 判断命令内容是否是纯分隔符（echo 后全是重复的分隔字符）
    private static func isSeparatorCommand(_ command: String) -> Bool {
        let content = command.trimmingCharacters(in: .whitespaces)
        guard content.hasPrefix("echo") else { return false }
        let afterEcho = content.dropFirst(4).trimmingCharacters(in: .whitespaces)
        guard afterEcho.count >= 3 else { return false }
        let separators = CharacterSet(charactersIn: "-=#*.")
        return afterEcho.unicodeScalars.allSatisfy { separators.contains($0) || $0 == " " }
    }

    /// 修复重复的命令 ID，返回是否有修复
    private static func fixDuplicateCommandIds(_ settings: inout AppSettings) -> Bool {
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
}

// MARK: - 配置管理器

@MainActor
final class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager(filePath: AppPaths.settingsFile)

    /// 对外只读：写入必须走 intent 方法，编译器强制收口
    @Published private(set) var settings: AppSettings = AppSettings()

    /// 配置是否已成功从磁盘加载（防止加载失败时空默认值覆盖真实配置）
    private var isLoaded = false

    private let filePath: URL
    private let resolvedFilePath: URL
    private let notificationManager = NotificationManager.shared

    // MARK: - 文件监听

    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var monitorFileDescriptor: Int32 = -1
    private var debounceTask: Task<Void, Never>?

    /// 注入文件路径与监听、错误通知开关；shared 走默认配置，测试走临时目录
    init(filePath: URL, enableFileMonitoring: Bool = true, notifyLoadError: Bool = true) {
        self.filePath = filePath
        // 初始化时一次性解析软链接
        if let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: filePath.path) {
            resolvedFilePath = URL(fileURLWithPath: resolved)
        } else {
            resolvedFilePath = filePath
        }
        load(notifyError: notifyLoadError)
        if enableFileMonitoring {
            startFileMonitoring()
        }
    }

    deinit {
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
        if monitorFileDescriptor >= 0 {
            close(monitorFileDescriptor)
        }
        debounceTask?.cancel()
    }

    private func startFileMonitoring() {
        // 先清掉旧监听（init 迁移路径会 save 后再 start，不清会泄漏 fd 和 source）
        stopFileMonitoring()
        let fd = open(resolvedFilePath.path, O_EVTONLY)
        guard fd >= 0 else { return }
        monitorFileDescriptor = fd

        fileMonitorSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: DispatchQueue(label: "com.menu-bar-executor.settings-monitor")
        )

        fileMonitorSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.handleFileChange()
            }
        }

        fileMonitorSource?.resume()
    }

    private func stopFileMonitoring() {
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
        if monitorFileDescriptor >= 0 {
            close(monitorFileDescriptor)
            monitorFileDescriptor = -1
        }
    }

    private func restartFileMonitoring() {
        stopFileMonitoring()
        startFileMonitoring()
    }

    private func handleFileChange() {
        // 到达这里的都是外部就地写：自身 save() 走原子替换（rename），不产生 .write 事件
        // 防抖：0.3 秒内多次变化只重载一次
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.reloadSilent()
        }
    }

    /// 自动重载（不弹通知，不弹错误）
    func reloadSilent() {
        load(notifyError: false)
        restartFileMonitoring()
    }

    // MARK: - 加载

    func load(notifyError: Bool = true) {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            // 文件不存在，视为首次安装，允许保存
            isLoaded = true
            return
        }
        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            settings = try decoder.decode(AppSettings.self, from: data)
            isLoaded = true
            if AppSettings.migrateIfNeeded(&settings) {
                save()
            }
        } catch {
            if notifyError {
                notificationManager.showConfigLoadError(error)
            }
        }
    }

    // MARK: - 保存

    /// 保存策略（isLoaded 守卫 + 原子写入 + 重建监听）是内部事务，不对外暴露
    private func save() {
        // 配置未加载成功时拒绝写入，防止空默认值覆盖真实配置
        guard isLoaded else { return }
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

            // 原子写入会替换 inode，旧文件描述符失效，需要重建监听
            restartFileMonitoring()
        } catch {
            print("AppSettingsManager save failed: \(error)")
        }
    }

    /// 更新面板帧（位置和尺寸）：写帧前先从磁盘加载最新配置，防止用旧内存数据覆盖外部修改
    func updatePaletteFrame(origin: CGPoint?, size: NSSize?) {
        load(notifyError: false)
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

    // MARK: - 设置项写入（intent 方法：改字段 + 保存一体）

    /// 设置开机自启：写配置 + 保存 + 同步系统登录项
    func setLaunchAtLogin(_ enabled: Bool) {
        guard settings.launchAtLogin != enabled else { return }
        settings.launchAtLogin = enabled
        save()
        LaunchAtLoginManager.shared.isEnabled = enabled
    }

    /// 启动时对齐开机自启状态：配置与系统不一致时以系统为准（用户可能在系统设置里改过）
    func reconcileLaunchAtLogin() {
        let systemState = LaunchAtLoginManager.shared.isEnabled
        if settings.launchAtLogin != systemState {
            settings.launchAtLogin = systemState
            save()
        }
    }

    func setDefaultInputSource(_ sourceID: String?) {
        settings.defaultInputSourceID = sourceID
        save()
    }

    func touchUpdateCheckDate() {
        settings.lastUpdateCheckDate = Date()
        save()
    }

    func setSkippedVersion(_ version: String?) {
        settings.skippedVersion = version
        save()
    }

    // MARK: - 命令管理

    /// 命令列表写入（save 内部自吞错误，无失败路径对外暴露）
    func saveCommands(_ commands: [Command]) {
        settings.commands = commands
        save()
    }

    // MARK: - 重载

    func reload() {
        load()
        notificationManager.showReloadSuccess()
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
        _ = AppSettings.migrateIfNeeded(&settings)
        save()
    }
}
