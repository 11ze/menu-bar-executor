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
}

final class ExecutionHistory: ObservableObject {
    static let shared = ExecutionHistory()

    @Published private(set) var records: [ExecutionRecord] = []

    private let maxRecords = 100

    private init() {
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

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: AppPaths.historyFile.path) else { return }

        do {
            let data = try Data(contentsOf: AppPaths.historyFile)
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
            try AppPaths.ensureDirectoryExists()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(records)
            try data.write(to: AppPaths.historyFile, options: .atomic)
        } catch {
            // 保存失败
        }
    }
}
