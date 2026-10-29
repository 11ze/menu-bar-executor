import SwiftUI

struct HistoryView: View {
    @ObservedObject private var history = ExecutionHistory.shared
    @State private var selectedID: UUID?
    @State private var showingClearConfirmation = false
    @State private var searchText = ""
    @State private var onlyFailed = false
    @State private var copied = false
    @FocusState private var searchFocused: Bool

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
                WindowHeader(title: "执行历史")
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundColor(InterfaceStyle.muted)
                        TextField("搜索命令名称", text: $searchText).textFieldStyle(.plain).focused($searchFocused)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark").frame(width: 24, height: 24).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("清空搜索")
                        }
                    }.modifier(ToolbarSearchStyle(focused: searchFocused))
                    Toggle("仅失败", isOn: $onlyFailed).font(.system(size: 10)).foregroundColor(InterfaceStyle.muted)
                    Button("清空历史") { showingClearConfirmation = true }.disabled(history.records.isEmpty)
                }.font(.system(size: 13)).padding(.horizontal, 20).padding(.vertical, 15).background(InterfaceStyle.material)
                Divider()
                if let record = selectedRecord {
                    HStack(spacing: 0) {
                        ScrollView {
                            LazyVStack(spacing: 3) {
                                ForEach(records) { item in
                                    Button { selectedID = item.id; copied = false } label: {
                                        VStack(alignment: .leading, spacing: 7) {
                                            HStack(spacing: 8) {
                                                Circle().fill(item.success ? InterfaceStyle.success : InterfaceStyle.failure).frame(width: 6, height: 6)
                                                Text(item.commandName).font(.system(size: 12, weight: .medium)).lineLimit(1).foregroundColor(InterfaceStyle.text)
                                                Spacer(minLength: 0)
                                            }
                                            (Text(item.executedAt, style: .date) + Text(" ") + Text(item.executedAt, style: .time)).font(.system(size: 10)).padding(.leading, 14)
                                        }.font(.system(size: 12)).foregroundColor(InterfaceStyle.muted)
                                            .padding(.horizontal, 12).padding(.vertical, 13).frame(maxWidth: .infinity, alignment: .leading)
                                            .background(item.id == record.id ? InterfaceStyle.selection : .clear)
                                            .cornerRadius(8).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                }
                            }.padding(8)
                        }.frame(width: min(280, geometry.size.width * 0.36)).background(InterfaceStyle.material)
                        Divider()
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(record.commandName).font(.system(size: 18, weight: .semibold)).textSelection(.enabled)
                                    HStack(spacing: 12) {
                                        Text(record.success ? "执行成功" : "执行失败").foregroundColor(record.success ? InterfaceStyle.success : InterfaceStyle.failure)
                                        Text(record.executedAt, style: .date) + Text(" ") + Text(record.executedAt, style: .time)
                                    }.font(.system(size: 11)).foregroundColor(InterfaceStyle.muted)
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("执行内容").font(.system(size: 10)).foregroundColor(InterfaceStyle.muted)
                                    Text(record.commandText).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                                }.padding(.top, 24)
                                HStack {
                                    Text("输出结果").font(.system(size: 10)).foregroundColor(InterfaceStyle.muted)
                                    Spacer()
                                    Button(copied ? "已复制" : "复制输出") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(record.output ?? "", forType: .string)
                                        copied = true
                                    }.font(.system(size: 10)).buttonStyle(CompactQuietButtonStyle()).disabled(record.output?.isEmpty != false)
                                }.padding(.top, 24).padding(.bottom, 8)
                                ScrollView {
                                    Text(record.output.flatMap { $0.isEmpty ? nil : $0 } ?? "（无输出）")
                                        .font(.system(size: 11, design: .monospaced)).lineSpacing(6).textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading).padding(15)
                                }.frame(minHeight: 143, maxHeight: 260)
                                    .background(InterfaceStyle.subtle)
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(InterfaceStyle.line, lineWidth: 1))
                                    .cornerRadius(7)
                                Text("每条记录最多保存 500 字符输出。").font(.system(size: 10)).foregroundColor(InterfaceStyle.muted).padding(.top, 8)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("›_").font(.system(size: 30, design: .monospaced)).opacity(0.55)
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
                }.font(.system(size: 11)).foregroundColor(InterfaceStyle.muted).padding(.horizontal, 20).padding(.vertical, 10)
                    .background(InterfaceStyle.chrome)
            }
        }
        .font(.system(size: 13)).foregroundColor(InterfaceStyle.text).background(InterfaceStyle.surface)
        .buttonStyle(InterfaceButtonStyle())
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .frame(minWidth: 640, minHeight: 420)
        .onChange(of: selectedRecord?.id) { _ in copied = false }
        .alert("确认清空", isPresented: $showingClearConfirmation) {
            Button("清空", role: .destructive) { history.clearHistory() }
            Button("取消", role: .cancel) {}
        } message: { Text("确定要清空所有执行记录吗？") }
    }
}
