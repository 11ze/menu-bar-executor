import Foundation

struct ExecutionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let commandName: String
    let commandText: String
    let executedAt: Date
    let success: Bool
    let output: String?

    init(command: Command, success: Bool, output: String?) {
        self.id = UUID()
        self.commandName = command.name
        self.commandText = command.command
        self.executedAt = Date()
        self.success = success
        self.output = output?.truncated(to: 500)
    }

    var formattedExecutedAt: String {
        Self.formatExecutedAt(executedAt)
    }

    private static let formatLock = NSLock()
    private static let cachedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    /// 紧凑中文时间展示：今天/昨天显示到秒，同年显示月日时分，跨年补年份。
    static func formatExecutedAt(
        _ date: Date,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> String {
        var cal = calendar
        cal.timeZone = timeZone
        formatLock.lock()
        defer { formatLock.unlock() }
        cachedFormatter.calendar = cal
        cachedFormatter.timeZone = timeZone
        if cal.isDate(date, inSameDayAs: now) {
            cachedFormatter.dateFormat = "HH:mm:ss"
            return "今天 " + cachedFormatter.string(from: date)
        }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: now),
           cal.isDate(date, inSameDayAs: yesterday) {
            cachedFormatter.dateFormat = "HH:mm:ss"
            return "昨天 " + cachedFormatter.string(from: date)
        }
        if cal.component(.year, from: date) == cal.component(.year, from: now) {
            cachedFormatter.dateFormat = "M月d日 HH:mm"
            return cachedFormatter.string(from: date)
        }
        cachedFormatter.dateFormat = "yyyy年M月d日 HH:mm"
        return cachedFormatter.string(from: date)
    }
}

@MainActor
final class ExecutionHistory: ObservableObject {
    static let shared = ExecutionHistory()

    @Published private(set) var records: [ExecutionRecord] = []

    private let maxRecords = 100
    private let filePath: URL

    /// 注入文件路径：shared 走默认路径，测试走临时目录
    init(filePath: URL = AppPaths.historyFile) {
        self.filePath = filePath
        loadHistory()
    }

    func addRecord(_ record: ExecutionRecord) {
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records.removeLast(records.count - maxRecords)
        }
        saveHistory()
    }

    func clearHistory() {
        records = []
        saveHistory()
    }

    /// 根据历史记录解析可执行命令：优先匹配当前配置中同名同原文的命令以保留目录与执行选项，找不到时按历史原文构造。
    nonisolated static func resolveCommand(for record: ExecutionRecord, in commands: [Command]) -> Command {
        if let matched = commands.first(where: { $0.name == record.commandName && $0.command == record.commandText }) {
            return matched
        }
        return Command(name: record.commandName, command: record.commandText)
    }

    /// 选中某条目标记录前，仅清除会隐藏该记录的筛选条件，避免通知定位或重跑成功后记录被静默过滤。
    nonisolated static func filtersEnsuringVisibility(
        of record: ExecutionRecord,
        searchText: String,
        onlyFailed: Bool
    ) -> (searchText: String, onlyFailed: Bool) {
        let nextOnlyFailed = onlyFailed && !record.success
        let nextSearch = CommandSearchMatcher.matches(record.commandName, query: searchText) ? searchText : ""
        return (nextSearch, nextOnlyFailed)
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: filePath.path) else { return }

        do {
            let data = try Data(contentsOf: filePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([ExecutionRecord].self, from: data)
            // 限制加载的记录数量
            if records.count > maxRecords {
                records = Array(records.prefix(maxRecords))
            }
        } catch {
            // 加载失败，使用空历史
        }
    }

    private func saveHistory() {
        do {
            try FileManager.default.createDirectory(
                at: filePath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(records)
            try data.write(to: filePath, options: .atomic)
        } catch {
            // 保存失败
        }
    }
}
