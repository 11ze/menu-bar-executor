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

// MARK: - PaletteCoordinator
// 协调器：连接 NSView 键盘事件和 SwiftUI 状态，统一管理搜索和选中状态
@MainActor
final class PaletteCoordinator: ObservableObject {
    static let shared = PaletteCoordinator()

    @Published var selectedIndex: Int = 0
    @Published var searchText: String = "" { didSet { updateFilteredCommands() } }
    @Published private(set) var filteredCommands: [Command] = []
    @Published var firstVisibleIndex: Int = 0  // 第一个可见行的索引（用于相对编号）

    private var cancellables = Set<AnyCancellable>()

    init() {
        filteredCommands = CommandsManager.shared.commands

        // 监听命令列表变化，自动更新过滤后的命令
        CommandsManager.shared.$commands
            .sink { [weak self] _ in
                self?.updateFilteredCommands()
            }
            .store(in: &cancellables)
    }

    private func updateFilteredCommands() {
        let newFiltered = CommandsManager.shared.filteredCommands(by: searchText)
        // 变化检测，避免无操作更新
        guard newFiltered != filteredCommands else { return }
        filteredCommands = newFiltered
        // 命令列表变化时修正选中状态
        if selectedIndex >= newFiltered.count {
            selectedIndex = max(0, newFiltered.count - 1)
        }
    }

    func refreshCommands() {
        updateFilteredCommands()
    }

    func moveUp() {
        if selectedIndex > 0 && filteredCommands.count > 0 {
            selectedIndex -= 1
        }
    }

    func moveDown() {
        if selectedIndex < filteredCommands.count - 1 {
            selectedIndex += 1
        }
    }

    func execute(_ command: Command) {
        CommandPaletteWindowController.shared.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + PaletteConfig.executionDelay) {
            CommandsManager.shared.execute(command)
        }
    }

    func executeSelected() {
        guard selectedIndex < filteredCommands.count else { return }
        execute(filteredCommands[selectedIndex])
    }

    func reset() {
        selectedIndex = 0
        searchText = ""  // didSet 会调用 updateFilteredCommands()
        firstVisibleIndex = 0
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
                        coordinator.selectedIndex = 0
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
                        ForEach(Array(coordinator.filteredCommands.enumerated()), id: \.element.id) { index, command in
                            let displayIndex = max(1, index - coordinator.firstVisibleIndex + 1)
                            CommandPaletteRow(
                                command: command,
                                displayIndex: displayIndex,
                                isSelected: index == coordinator.selectedIndex,
                                searchText: coordinator.searchText
                            )
                            .id(command.id)
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
                    guard newIndex < coordinator.filteredCommands.count else { return }
                    let targetId = coordinator.filteredCommands[newIndex].id
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
}

struct CommandPaletteRow: View {
    let command: Command
    let displayIndex: Int
    let isSelected: Bool
    let searchText: String

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
                HighlightedText(text: command.name, search: searchText)
                    .font(.body)
                    .foregroundColor(.primary)
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
