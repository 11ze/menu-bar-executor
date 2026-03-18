import SwiftUI

struct HistoryView: View {
    @ObservedObject private var history = ExecutionHistory.shared
    @State private var selectedRecord: ExecutionRecord?
    @Environment(\.dismiss) private var dismiss

    // 使用静态常量避免每次渲染重新创建 DateFormatter
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Text("执行历史")
                    .font(.headline)
                Spacer()
                if !history.records.isEmpty {
                    Button("清空历史") {
                        history.clearHistory()
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if history.records.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("暂无执行记录")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedRecord) {
                    ForEach(history.records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(record.success ? .green : .red)
                                Text(record.commandName)
                                    .font(.body)
                                Spacer()
                                Text(Self.dateFormatter.string(from: record.executedAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(record.commandText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                        .tag(record)
                    }
                }

                // 详情面板
                if let record = selectedRecord {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("输出结果")
                            .font(.headline)
                        ScrollView {
                            Text(record.output ?? "（无输出）")
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .frame(height: 150)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 450)
    }
}

#Preview {
    HistoryView()
}
