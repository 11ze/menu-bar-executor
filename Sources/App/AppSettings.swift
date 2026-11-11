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

    var autoCheckUpdates: Bool = true

    enum CodingKeys: String, CodingKey {
        case commands
        case palettePosition
        case paletteSize
        case defaultInputSourceID
        case launchAtLogin
        case lastUpdateCheckDate
        case skippedVersion
        case groupOrder
        case autoCheckUpdates
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoCheckUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoCheckUpdates) ?? true
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
        try container.encode(autoCheckUpdates, forKey: .autoCheckUpdates)
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
    @Published var lastError: AppError?

    /// 配置是否已成功从磁盘加载（防止加载失败时空默认值覆盖真实配置）
    private var isLoaded = false
    /// 最近一次加载失败的原因：未加载成功时拒写，用它报告真实原因，避免虚构“文件损坏”
    private var loadError: Error?

    private let filePath: URL
    private let resolvedFilePath: URL
    private let notificationManager = NotificationManager.shared

    // MARK: - 文件监听

    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var directoryMonitorSource: DispatchSourceFileSystemObject?
    private let enableFileMonitoring: Bool
    private var debounceTask: Task<Void, Never>?
    /// reloadSilent 乱序守卫：并发发起多次后台重载时，只应用最新一次的结果
    private var reloadToken = 0

    /// 注入文件路径与监听、错误通知开关；shared 走默认配置，测试走临时目录
    init(filePath: URL, enableFileMonitoring: Bool = true, notifyLoadError: Bool = true) {
        self.filePath = filePath
        self.enableFileMonitoring = enableFileMonitoring
        // resolvingSymlinksInPath 对目标不存在的链接会返回链接自身，必须先读目的地。
        if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: filePath.path) {
            let target = destination.hasPrefix("/")
                ? URL(fileURLWithPath: destination)
                : filePath.deletingLastPathComponent().appendingPathComponent(destination)
            resolvedFilePath = target.standardizedFileURL.resolvingSymlinksInPath()
        } else {
            resolvedFilePath = filePath.resolvingSymlinksInPath()
        }
        load(notifyError: notifyLoadError)
        if enableFileMonitoring {
            startFileMonitoring()
        }
    }

    deinit {
        fileMonitorSource?.cancel()
        directoryMonitorSource?.cancel()
        debounceTask?.cancel()
    }

    private func startFileMonitoring() {
        guard enableFileMonitoring else { return }
        stopFileMonitoring()
        if directoryMonitorSource == nil {
            let directory = resolvedFilePath.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // 目录监听覆盖文件不存在、删除后重建及原子替换；文件监听覆盖就地修改。
            directoryMonitorSource = makeMonitor(at: directory, events: .write)
        }
        fileMonitorSource = makeMonitor(at: resolvedFilePath, events: [.write, .delete, .rename])
    }

    private func makeMonitor(at url: URL, events: DispatchSource.FileSystemEvent) -> DispatchSourceFileSystemObject? {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: events,
            queue: DispatchQueue(label: "com.menu-bar-executor.settings-monitor")
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in self?.handleFileChange() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }

    private func stopFileMonitoring() {
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
    }

    private func handleFileChange() {
        // 到达这里的有外部就地写（.write）和外部原子替换（.rename/.delete）；
        // 自身 save() 的原子替换也会经旧 fd 绕一圈到达，读回相同内容后自然吸收，无需跳过标志
        // 防抖：0.3 秒内多次变化只重载一次
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.reloadSilent()
        }
    }

    /// 统一解码入口：iso8601 日期策略是所有读盘路径（load / reloadSilent / importSettings）的共同契约
    nonisolated private static func decodeSettings(from data: Data) throws -> AppSettings {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppSettings.self, from: data)
    }

    /// 统一编码入口：所有写盘路径（save / exportSettings）共用同一格式契约，与 decodeSettings 对称
    private static func encodeSettings(_ settings: AppSettings) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(settings)
    }

    /// 自动重载（不弹通知，不弹错误）：读盘+解码在后台，主线程只应用结果，
    /// 调用方（面板 show / 文件监听防抖）不承担磁盘 IO 的主线程阻塞
    func reloadSilent() {
        reloadToken += 1
        let token = reloadToken
        let path = filePath.path

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 读盘或解码失败也要回主线程重建监听：外部原子替换写坏文件后旧 fd 已失效，
            // 不重建则坏文件期间的后续外部修改全部丢失（重建幂等，文件不存在时自动 no-op）
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let decoded = try? Self.decodeSettings(from: data) else {
                Task { @MainActor [weak self] in
                    self?.startFileMonitoring()
                }
                return
            }

            Task { @MainActor [weak self] in
                guard let self, token == self.reloadToken else { return }
                var candidate = decoded
                if AppSettings.migrateIfNeeded(&candidate) {
                    do { try self.save(candidate) }
                    catch { self.lastError = .configSaveFailed(error) }
                } else {
                    if self.settings != candidate { self.settings = candidate }
                    self.isLoaded = true
                }
                self.startFileMonitoring()
            }
        }
    }

    // MARK: - 加载

    @discardableResult
    func load(notifyError: Bool = true) -> Bool {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            // 仅首次安装允许使用空默认值；已有配置丢失时保留最后成功的快照。
            reloadToken += 1
            if isLoaded {
                if notifyError { notificationManager.showConfigLoadError(CocoaError(.fileNoSuchFile)) }
                return false
            }
            isLoaded = true
            return true
        }
        do {
            let data = try Data(contentsOf: filePath)
            var decoded = try Self.decodeSettings(from: data)
            if AppSettings.migrateIfNeeded(&decoded) {
                try save(decoded)
            } else {
                reloadToken += 1
                settings = decoded
                isLoaded = true
            }
            return true
        } catch {
            loadError = error
            if notifyError { notificationManager.showConfigLoadError(error) }
            return false
        }
    }

    // MARK: - 保存

    /// 先写盘，成功后发布配置；失败保留原快照。
    private func save(_ candidate: AppSettings) throws {
        reloadToken += 1
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: resolvedFilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try Self.encodeSettings(candidate)
        try data.write(to: resolvedFilePath, options: .atomic)
        settings = candidate
        isLoaded = true
        lastError = nil
        startFileMonitoring()
    }

    @discardableResult
    private func commit(_ change: (inout AppSettings) -> Void) -> Bool {
        guard isLoaded else {
            lastError = .configSaveFailed(loadError ?? CocoaError(.fileReadCorruptFile))
            return false
        }
        var candidate = settings
        change(&candidate)
        do {
            try save(candidate)
            return true
        } catch {
            lastError = .configSaveFailed(error)
            return false
        }
    }

    @discardableResult
    func updatePaletteFrame(origin: CGPoint?, size: NSSize?) -> Bool {
        guard (origin != nil && origin != settings.palettePosition)
                || (size != nil && size != settings.paletteSize) else { return true }
        return commit {
            if let origin { $0.palettePosition = origin }
            if let size { $0.paletteSize = size }
        }
    }

    // MARK: - 设置项写入

    @discardableResult
    func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        guard settings.launchAtLogin != enabled else { return true }
        guard commit({ $0.launchAtLogin = enabled }) else { return false }
        LaunchAtLoginManager.shared.isEnabled = enabled
        return true
    }

    func reconcileLaunchAtLogin() {
        let systemState = LaunchAtLoginManager.shared.isEnabled
        if settings.launchAtLogin != systemState {
            commit { $0.launchAtLogin = systemState }
        }
    }

    @discardableResult
    func setDefaultInputSource(_ sourceID: String?) -> Bool {
        commit { $0.defaultInputSourceID = sourceID }
    }

    @discardableResult
    func setAutoCheckUpdates(_ enabled: Bool) -> Bool {
        commit { $0.autoCheckUpdates = enabled }
    }

    @discardableResult
    func touchUpdateCheckDate() -> Bool {
        commit { $0.lastUpdateCheckDate = Date() }
    }

    @discardableResult
    func setSkippedVersion(_ version: String?) -> Bool {
        commit { $0.skippedVersion = version }
    }

    // MARK: - 命令管理

    @discardableResult
    func saveCommands(_ commands: [Command]) -> Bool {
        commit { $0.commands = commands }
    }

    // MARK: - 重载

    func reload() {
        if load() { notificationManager.showReloadSuccess() }
    }

    // MARK: - 导入导出

    func exportSettings(to url: URL) throws {
        let data = try Self.encodeSettings(settings)
        try data.write(to: url)
    }

    func importSettings(from url: URL) throws {
        let data = try Data(contentsOf: url)
        var candidate = try Self.decodeSettings(from: data)
        AppSettings.migrateIfNeeded(&candidate)
        try save(candidate)
    }
}
