import SwiftUI

struct HistoryView: View {
    @ObservedObject private var history = ExecutionHistory.shared
    @State private var selectedID: UUID?
    @State private var showingClearConfirmation = false
    @State private var searchText = ""
    @State private var onlyFailed = false
    @State private var copied = false

    private var records: [ExecutionRecord] {
        history.records.filter {
            (!onlyFailed || !$0.success) && (searchText.isEmpty || $0.commandName.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var selectedRecord: ExecutionRecord? {
        records.first(where: { $0.id == selectedID }) ?? records.first
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(InterfaceStyle.muted)
                        TextField("搜索命令名称", text: $searchText).textFieldStyle(.plain)
                    }.padding(9).background(InterfaceStyle.surface).clipShape(Capsule())
                    Toggle("仅失败", isOn: $onlyFailed)
                    Button("清空历史") { showingClearConfirmation = true }.disabled(history.records.isEmpty)
                }.padding(16).background(InterfaceStyle.material)
                Divider()
                if let record = selectedRecord {
                    HStack(spacing: 0) {
                        ScrollView {
                            LazyVStack(spacing: 3) {
                                ForEach(records) { item in
                                    Button { selectedID = item.id; copied = false } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: item.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                    .foregroundColor(item.success ? .green : .red)
                                                Text(item.commandName).lineLimit(1).foregroundColor(.primary)
                                                Spacer(minLength: 0)
                                            }
                                            Text(item.executedAt, style: .date) + Text(" ") + Text(item.executedAt, style: .time)
                                        }.font(.system(size: 12)).foregroundColor(InterfaceStyle.muted)
                                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                            .background(item.id == record.id ? InterfaceStyle.selection : .clear)
                                            .cornerRadius(11).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                }
                            }.padding(8)
                        }.frame(width: min(310, geometry.size.width * 0.4)).background(InterfaceStyle.material)
                        Divider()
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(record.commandName).font(.headline).textSelection(.enabled)
                                    Text(record.success ? "成功" : "失败").foregroundColor(record.success ? .green : .red)
                                    Text(record.executedAt, style: .date) + Text(" ") + Text(record.executedAt, style: .time)
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("执行内容").font(.caption).fontWeight(.semibold)
                                    Text(record.commandText).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                                }
                                HStack {
                                    Text("输出结果").font(.caption).fontWeight(.semibold)
                                    Spacer()
                                    Button(copied ? "已复制" : "复制输出") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(record.output ?? "", forType: .string)
                                        copied = true
                                    }.disabled(record.output?.isEmpty != false)
                                }
                                ScrollView {
                                    Text(record.output.flatMap { $0.isEmpty ? nil : $0 } ?? "（无输出）")
                                        .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                                }.frame(minHeight: 190, maxHeight: 300)
                                    .background(InterfaceStyle.surface).cornerRadius(6)
                                Text("每条记录最多保存 500 字符输出。").font(.caption).foregroundColor(InterfaceStyle.muted)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath").font(.largeTitle)
                        Text(history.records.isEmpty ? "暂无执行记录" : "没有匹配的记录")
                        if !searchText.isEmpty || onlyFailed {
                            Button("清除筛选") { searchText = ""; onlyFailed = false }
                        } else {
                            Button("打开命令面板") { CommandPaletteWindowController.shared.show() }
                        }
                    }.foregroundColor(InterfaceStyle.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Divider()
                HStack {
                    Text("\(records.count) 条记录")
                    Spacer()
                    Text("最近 100 条 · 不含自动执行")
                }.font(.caption).foregroundColor(InterfaceStyle.muted).padding(.horizontal, 20).padding(.vertical, 10)
            }
        }
        .font(.system(size: 13)).foregroundColor(InterfaceStyle.text).background(InterfaceStyle.surface)
        .frame(minWidth: 640, minHeight: 420)
        .onChange(of: selectedRecord?.id) { _ in copied = false }
        .alert("确认清空", isPresented: $showingClearConfirmation) {
            Button("清空", role: .destructive) { history.clearHistory() }
            Button("取消", role: .cancel) {}
        } message: { Text("确定要清空所有执行记录吗？") }
    }
}
