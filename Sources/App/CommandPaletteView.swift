import Combine
import SwiftUI

// MARK: - 面板配置常量
enum PaletteConfig {
    /// 面板关闭动画完成后执行命令的延迟
    static let executionDelay: TimeInterval = 0.1
    /// 焦点设置延迟（确保窗口完全显示）
    static let focusDelay: TimeInterval = 0.05
    /// 默认尺寸
    static let defaultWidth: CGFloat = 500
    static let defaultHeight: CGFloat = 480
    /// 尺寸范围
    static let minWidth: CGFloat = 300
    static let minHeight: CGFloat = 250
    static let maxWidth: CGFloat = 800
    static let maxHeight: CGFloat = 1000
    /// 快捷键最大数量（⌘+1 到 ⌘+9）
    static let maxQuickSelectCount = 9
    /// 滚动位置容差（像素）
    static let scrollPositionTolerance: CGFloat = 10
}

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

// MARK: - 自动执行状态
enum AutoExecuteState {
    case loading
    case success(String)
    case failure(String)
}

// MARK: - 面板列表项
enum PaletteItem: Identifiable, Equatable {
    case groupHeader(String)
    case command(Command, displayIndex: Int)

    var id: String {
        switch self {
        case .groupHeader(let name): return "header-\(name)"
        case .command(let cmd, _): return "cmd-\(cmd.id.uuidString)"
        }
    }

    var isCommand: Bool {
        if case .command = self { return true }
        return false
    }

    var command: Command? {
        if case .command(let cmd, _) = self { return cmd }
        return nil
    }
}

// MARK: - PaletteCoordinator
// 协调器：连接 NSView 键盘事件和 SwiftUI 状态，统一管理搜索和选中状态
@MainActor
final class PaletteCoordinator: ObservableObject {
    static let shared = PaletteCoordinator()

    @Published var selectedIndex: Int = 0
    @Published var searchText: String = "" { didSet { updatePaletteItems() } }
    @Published private(set) var paletteItems: [PaletteItem] = []
    @Published var firstVisibleIndex: Int = 0  // 第一个可见行的索引（用于相对编号）
    @Published var autoExecuteResults: [UUID: AutoExecuteState] = [:]

    private var cancellables = Set<AnyCancellable>()

    init() {
        paletteItems = buildPaletteItems(from: CommandsManager.shared.commands)

        // 监听命令列表变化，自动更新
        CommandsManager.shared.$commands
            .sink { [weak self] _ in
                self?.updatePaletteItems()
            }
            .store(in: &cancellables)
    }

    private func buildPaletteItems(from commands: [Command]) -> [PaletteItem] {
        let grouped = Dictionary(grouping: commands, by: { $0.group?.isEmpty == true ? nil : $0.group })
        let sortedGroups = CommandsManager.shared.sortedGroupNames(from: commands)

        var items: [PaletteItem] = []
        var displayIndex = 1

        for group in sortedGroups {
            guard let groupCommands = grouped[group] else { continue }

            if let groupName = group {
                items.append(.groupHeader(groupName))
            }

            for cmd in groupCommands {
                items.append(.command(cmd, displayIndex: displayIndex))
                displayIndex += 1
            }
        }

        return items
    }

    private func updatePaletteItems() {
        let filtered = CommandsManager.shared.filteredCommands(by: searchText)
        let newItems = buildPaletteItems(from: filtered)
        guard newItems != paletteItems else { return }
        paletteItems = newItems
        adjustSelectedIndex()
    }

    private func adjustSelectedIndex() {
        if paletteItems.isEmpty {
            selectedIndex = 0
            return
        }
        if selectedIndex >= paletteItems.count {
            selectedIndex = 0
        }
        // 向后找最近的 command 项
        for i in selectedIndex..<paletteItems.count {
            if paletteItems[i].isCommand { selectedIndex = i; return }
        }
        // 从头找
        for i in 0..<selectedIndex {
            if paletteItems[i].isCommand { selectedIndex = i; return }
        }
        selectedIndex = 0
    }

    func refreshCommands() {
        updatePaletteItems()
    }

    func moveUp() {
        var idx = selectedIndex - 1
        while idx >= 0 && !paletteItems[idx].isCommand { idx -= 1 }
        if idx >= 0 { selectedIndex = idx }
    }

    func moveDown() {
        var idx = selectedIndex + 1
        while idx < paletteItems.count && !paletteItems[idx].isCommand { idx += 1 }
        if idx < paletteItems.count { selectedIndex = idx }
    }

    func execute(_ command: Command) {
        CommandPaletteWindowController.shared.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + PaletteConfig.executionDelay) {
            CommandsManager.shared.execute(command)
        }
    }

    func executeSelected() {
        guard selectedIndex < paletteItems.count,
              let cmd = paletteItems[selectedIndex].command else { return }
        execute(cmd)
    }

    func reset() {
        selectedIndex = 0
        searchText = ""  // didSet 会调用 updatePaletteItems()
        firstVisibleIndex = 0
        autoExecuteResults.removeAll()
    }

    func executeAutoCommands() {
        let autoCommands = paletteItems.compactMap { item -> Command? in
            guard case .command(let cmd, _) = item, cmd.autoExecute else { return nil }
            return cmd
        }
        guard !autoCommands.isEmpty else { return }

        for command in autoCommands {
            autoExecuteResults[command.id] = .loading

            CommandExecutor.shared.execute(command: command) { [weak self] success, output in
                guard let self else { return }
                let trimmed = output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if success {
                    self.autoExecuteResults[command.id] = .success(trimmed)
                } else {
                    self.autoExecuteResults[command.id] = .failure(trimmed.isEmpty ? "执行失败" : trimmed)
                }
            }
        }
    }

    func clearSearch() {
        searchText = ""
    }
}

// MARK: - CommandPaletteView
struct CommandPaletteView: View {
    @ObservedObject private var manager = CommandsManager.shared
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
                        coordinator.selectedIndex = coordinator.paletteItems.firstIndex(where: { $0.isCommand }) ?? 0
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
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // 命令列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(coordinator.paletteItems.enumerated()), id: \.element.id) { index, item in
                            switch item {
                            case .groupHeader(let groupName):
                                GroupHeaderRow(title: groupName)
                                    .id(item.id)
                            case .command(let command, let absoluteIndex):
                                let displayIndex = relativeDisplayIndex(for: absoluteIndex, at: coordinator.firstVisibleIndex)
                                CommandPaletteRow(
                                    command: command,
                                    displayIndex: displayIndex,
                                    isSelected: index == coordinator.selectedIndex,
                                    searchText: coordinator.searchText,
                                    autoExecuteState: coordinator.autoExecuteResults[command.id]
                                )
                                .id(item.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    coordinator.execute(command)
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
                    if let first = positions.filter({ $0.minY >= -tolerance }).min(by: { abs($0.minY) < abs($1.minY) }),
                       coordinator.firstVisibleIndex != first.index {
                        coordinator.firstVisibleIndex = first.index
                    }
                }
                .onChange(of: coordinator.selectedIndex) { newIndex in
                    guard newIndex < coordinator.paletteItems.count else { return }
                    let targetId = coordinator.paletteItems[newIndex].id
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(targetId, anchor: .center)
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

    /// 根据绝对 displayIndex 和 firstVisibleIndex 计算相对快捷键编号
    private func relativeDisplayIndex(for absoluteIndex: Int, at firstVisiblePaletteIndex: Int) -> Int {
        let items = coordinator.paletteItems
        // 找到 firstVisibleIndex 处或之后的第一个 command 项的绝对编号
        var firstVisibleAbsoluteIndex = 1
        for i in max(0, firstVisiblePaletteIndex)..<items.count {
            if case .command(_, let idx) = items[i] {
                firstVisibleAbsoluteIndex = idx
                break
            }
        }
        return max(1, absoluteIndex - firstVisibleAbsoluteIndex + 1)
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

    @State private var isHovered = false

    private var rowBackground: Color {
        if isSelected {
            Color.accentColor.opacity(0.15)
        } else if isHovered {
            Color.primary.opacity(0.05)
        } else {
            Color.clear
        }
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
                        if !output.isEmpty {
                            Text(output)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                case .failure(let error):
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        HighlightedText(text: command.name, search: searchText)
                            .font(.caption)
                            .foregroundColor(.secondary)
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
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }
}
