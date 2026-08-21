import SwiftUI

// MARK: - 行位置 PreferenceKey
private struct RowPosition: Equatable {
    let index: Int
    let minY: CGFloat
}

private struct RowPositionsPreferenceKey: PreferenceKey {
    static var defaultValue: [RowPosition] = []
    static func reduce(value: inout [RowPosition], nextValue: () -> [RowPosition]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - CommandPaletteView
struct CommandPaletteView: View {
    @ObservedObject private var coordinator = PaletteCoordinator.shared

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索命令...", text: $coordinator.searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onChange(of: coordinator.searchText) { _ in
                        // 重置到第一个可执行命令项（跳过 groupHeader）
                        coordinator.selectFirstCommand()
                    }
                if !coordinator.searchText.isEmpty {
                    Button(action: {
                        coordinator.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 空状态：无命令或搜索无结果
            if coordinator.listModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: coordinator.searchText.isEmpty ? "terminal" : "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(coordinator.searchText.isEmpty ? "暂无命令，打开设置添加" : "未找到匹配命令")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            // 命令列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(coordinator.listModel.items.enumerated()), id: \.element.id) { index, item in
                            switch item {
                            case .groupHeader(let groupName):
                                GroupHeaderRow(title: groupName)
                                    .id(item.id)
                            case .command(let command, let absoluteIndex):
                                CommandPaletteRow(
                                    command: command,
                                    displayIndex: coordinator.listModel.relativeDisplayIndex(forAbsolute: absoluteIndex),
                                    isSelected: index == coordinator.listModel.selectedIndex,
                                    searchText: coordinator.searchText,
                                    autoExecuteState: coordinator.autoExecuteResults[command.id]
                                )
                                .id(item.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    coordinator.execute(command)
                                }
                                .onHover { hovering in
                                    if hovering { coordinator.selectOnHover(index) }
                                }
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: RowPositionsPreferenceKey.self,
                                            value: [RowPosition(index: index, minY: geo.frame(in: .named("scroll")).minY)]
                                        )
                                    }
                                )
                            }
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(RowPositionsPreferenceKey.self) { positions in
                    // 找到 minY 最接近 0 且在容差范围内的行作为第一个可见行
                    let tolerance = PaletteConfig.scrollPositionTolerance
                    if let first = positions.filter({ $0.minY >= -tolerance }).min(by: { abs($0.minY) < abs($1.minY) }) {
                        coordinator.updateFirstVisibleIndex(first.index)
                    }
                }
                .onChange(of: coordinator.scrollRequest) { target in
                    guard let target, target < coordinator.listModel.items.count else { return }
                    let targetId = coordinator.listModel.items[target].id
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(targetId, anchor: .center)
                    }
                    coordinator.scrollRequest = nil
                }
            }
            }

            // 底部提示
            HStack {
                Text("↵ 回车 / 点击 / ⌘+数字 执行")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("↑↓ 导航")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Esc 关闭")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            coordinator.refreshCommands()
            coordinator.reset()
            // 延迟设置焦点，确保窗口已完全显示
            DispatchQueue.main.asyncAfter(deadline: .now() + PaletteConfig.focusDelay) {
                isSearchFocused = true
            }
        }
        .onDisappear {
            coordinator.reset()
        }
    }
}

// MARK: - 分组标题行
struct GroupHeaderRow: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

struct CommandPaletteRow: View {
    let command: Command
    let displayIndex: Int
    let isSelected: Bool
    let searchText: String
    let autoExecuteState: AutoExecuteState?

    private var rowBackground: Color {
        isSelected ? Color.accentColor.opacity(0.15) : .clear
    }

    var body: some View {
        HStack(spacing: 12) {
            // 显示索引，仅 1-9 显示快捷键提示
            Group {
                if displayIndex <= PaletteConfig.maxQuickSelectCount {
                    Text("\(displayIndex)")
                        .foregroundColor(.secondary)
                } else {
                    Text(" ")
                }
            }
            .font(.caption)
            .frame(width: 16, height: 16, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                switch autoExecuteState {
                case .loading:
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(command.name)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text("执行中...")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                case .success(let output):
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        HighlightedText(text: command.name, search: searchText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .layoutPriority(1)
                        if !output.isEmpty {
                            Text(output)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                case .failure(let error):
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        HighlightedText(text: command.name, search: searchText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .layoutPriority(1)
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                case .none:
                    HStack(spacing: 4) {
                        if command.autoExecute {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        HighlightedText(text: command.name, search: searchText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
                if let wd = command.workingDirectory, !wd.isEmpty {
                    Text(wd)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
        .contentShape(Rectangle())
    }
}
