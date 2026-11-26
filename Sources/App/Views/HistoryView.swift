import SwiftUI

struct HistoryView: View {
    @ObservedObject private var history = ExecutionHistory.shared
    @ObservedObject private var navigation = HistoryNavigationState.shared
    @State private var selectedID: UUID?
    @State private var showingClearConfirmation = false
    @State private var searchText = ""
    @State private var onlyFailed = false
    @State private var copiedOutput = false
    @State private var copiedCommand = false
    @State private var rerunningRecordID: UUID?
    @State private var scrollTargetID: UUID?

    private var records: [ExecutionRecord] {
        history.records.filter {
            (!onlyFailed || !$0.success) && CommandSearchMatcher.matches($0.commandName, query: searchText)
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
                    ToolbarSearchField(placeholder: "搜索命令名称", text: $searchText)
                    Toggle("仅失败", isOn: $onlyFailed)
                        .toggleStyle(InterfaceCheckboxToggleStyle())
                        .font(.system(size: 12)).foregroundColor(InterfaceStyle.muted)
                    Button("清空历史") { showingClearConfirmation = true }.disabled(history.records.isEmpty)
                }.font(.system(size: 13)).padding(.horizontal, 20).padding(.vertical, 15).background(InterfaceStyle.material)
                Divider()
                if let record = selectedRecord {
                    HStack(spacing: 0) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 3) {
                                    ForEach(records) { item in
                                        let isSelected = item.id == record.id
                                        Button {
                                            selectedID = item.id
                                            copiedOutput = false
                                            copiedCommand = false
                                        } label: {
                                            VStack(alignment: .leading, spacing: 7) {
                                                HStack(spacing: 8) {
                                                    Circle().fill(item.success ? InterfaceStyle.success : InterfaceStyle.failure).frame(width: 6, height: 6)
                                                    HighlightedText(
                                                        text: item.commandName,
                                                        search: searchText,
                                                        highlight: isSelected ? InterfaceStyle.selectedRowText : InterfaceStyle.selectedText
                                                    )
                                                        .font(.system(size: 12, weight: .medium))
                                                        .lineLimit(1)
                                                        .foregroundColor(isSelected ? InterfaceStyle.selectedRowText : InterfaceStyle.text)
                                                    if !item.success {
                                                        Text("失败").font(.system(size: 12, weight: .medium)).foregroundColor(InterfaceStyle.failure).fixedSize()
                                                    }
                                                    Spacer(minLength: 0)
                                                }
                                                Text(item.formattedExecutedAt).font(.system(size: 12)).padding(.leading, 14)
                                            }.font(.system(size: 12)).foregroundColor(InterfaceStyle.muted)
                                                .padding(.horizontal, 12).padding(.vertical, 13).frame(maxWidth: .infinity, alignment: .leading)
                                                .background(isSelected ? InterfaceStyle.selection : .clear)
                                                .cornerRadius(8).contentShape(Rectangle())
                                        }.buttonStyle(.plain)
                                            .id(item.id)
                                    }
                                }.padding(8)
                            }
                            .onChange(of: scrollTargetID) { target in
                                guard let target else { return }
                                DispatchQueue.main.async {
                                    proxy.scrollTo(target)
                                    scrollTargetID = nil
                                }
                            }
                            .onAppear {
                                if let target = scrollTargetID {
                                    DispatchQueue.main.async {
                                        proxy.scrollTo(target)
                                        scrollTargetID = nil
                                    }
                                }
                            }
                        }.frame(width: min(280, geometry.size.width * 0.36)).background(InterfaceStyle.material)
                        Divider()
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 9) {
                                        Text(record.commandName).font(.system(size: 18, weight: .semibold)).textSelection(.enabled)
                                        HStack(spacing: 12) {
                                            Text(record.success ? "执行成功" : "执行失败").foregroundColor(record.success ? InterfaceStyle.success : InterfaceStyle.failure)
                                            Text(record.formattedExecutedAt)
                                        }.font(.system(size: 12)).foregroundColor(InterfaceStyle.muted)
                                    }
                                    Spacer(minLength: 8)
                                    Button {
                                        rerun(record)
                                    } label: {
                                        Label(rerunningRecordID == record.id ? "执行中…" : "重新执行", systemImage: "arrow.clockwise")
                                    }
                                    .font(.system(size: 12))
                                    .buttonStyle(InterfaceButtonStyle(height: 28))
                                    .disabled(rerunningRecordID != nil)
                                    .fixedSize()
                                }
                                HStack {
                                    Text("执行内容").font(.system(size: 12)).foregroundColor(InterfaceStyle.muted)
                                    Spacer()
                                    Button(copiedCommand ? "已复制" : "复制命令") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(record.commandText, forType: .string)
                                        copiedCommand = true
                                    }.font(.system(size: 12)).buttonStyle(CompactQuietButtonStyle()).disabled(record.commandText.isEmpty)
                                }.padding(.top, 22).padding(.bottom, 8)
                                Text(record.commandText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .lineSpacing(5)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(InterfaceStyle.subtle)
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(InterfaceStyle.line, lineWidth: 1))
                                    .cornerRadius(7)
                                HStack {
                                    Text("输出结果").font(.system(size: 12)).foregroundColor(InterfaceStyle.muted)
                                    Spacer()
                                    Button(copiedOutput ? "已复制" : "复制输出") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(record.output ?? "", forType: .string)
                                        copiedOutput = true
                                    }.font(.system(size: 12)).buttonStyle(CompactQuietButtonStyle()).disabled(record.output?.isEmpty != false)
                                }.padding(.top, 20).padding(.bottom, 8)
                                ScrollView {
                                    Text(record.output.flatMap { $0.isEmpty ? nil : $0 } ?? "（无输出）")
                                        .font(.system(size: 12, design: .monospaced)).lineSpacing(6).textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading).padding(15)
                                }.frame(maxHeight: 260)
                                    .background(InterfaceStyle.subtle)
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(InterfaceStyle.line, lineWidth: 1))
                                    .cornerRadius(7)
                                Text("每条记录最多保存 500 字符输出。").font(.system(size: 12)).foregroundColor(InterfaceStyle.muted).padding(.top, 8)
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
                }.font(.system(size: 12)).foregroundColor(InterfaceStyle.muted).padding(.horizontal, 20).padding(.vertical, 10)
                    .background(InterfaceStyle.chrome)
            }
        }
        .font(.system(size: 13)).foregroundColor(InterfaceStyle.text).background(InterfaceStyle.surface)
        .buttonStyle(InterfaceButtonStyle())
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .frame(minWidth: 640, minHeight: 420)
        .ignoresSafeArea(edges: .top)
        .onAppear { consumeRequestedRecord() }
        .onChange(of: navigation.requestedRecordID) { _ in consumeRequestedRecord() }
        .onChange(of: selectedRecord?.id) { _ in
            copiedOutput = false
            copiedCommand = false
        }
        .alert("确认清空", isPresented: $showingClearConfirmation) {
            Button("清空", role: .destructive) { history.clearHistory() }
            Button("取消", role: .cancel) {}
        } message: { Text("确定要清空所有执行记录吗？") }
    }

    private func consumeRequestedRecord() {
        guard let targetID = navigation.requestedRecordID else { return }
        navigation.requestedRecordID = nil
        if let target = history.records.first(where: { $0.id == targetID }) {
            selectRecordEnsuringVisible(target)
        }
    }

    private func rerun(_ record: ExecutionRecord) {
        guard rerunningRecordID == nil else { return }
        rerunningRecordID = record.id
        let command = ExecutionHistory.resolveCommand(for: record, in: CommandsManager.shared.commands)
        CommandExecutor.shared.execute(command: command, mode: .userInitiated) { _ in
            rerunningRecordID = nil
            if let newest = history.records.first {
                selectRecordEnsuringVisible(newest)
            }
        }
    }

    private func selectRecordEnsuringVisible(_ record: ExecutionRecord) {
        let adjusted = ExecutionHistory.filtersEnsuringVisibility(
            of: record,
            searchText: searchText,
            onlyFailed: onlyFailed
        )
        searchText = adjusted.searchText
        onlyFailed = adjusted.onlyFailed
        selectedID = record.id
        scrollTargetID = record.id
    }
}
