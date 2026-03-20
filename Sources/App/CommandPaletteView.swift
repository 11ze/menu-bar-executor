import SwiftUI

// MARK: - 面板配置常量
enum PaletteConfig {
    /// 面板关闭动画完成后执行命令的延迟
    static let executionDelay: TimeInterval = 0.1
    /// 焦点设置延迟（确保窗口完全显示）
    static let focusDelay: TimeInterval = 0.05
    static let width: CGFloat = 500
    static let totalHeight: CGFloat = 380
    static let maxVisibleItems = 8
}

// MARK: - PaletteCoordinator
// 协调器：连接 NSView 键盘事件和 SwiftUI 状态，统一管理搜索和选中状态
@MainActor
final class PaletteCoordinator: ObservableObject {
    static let shared = PaletteCoordinator()

    @Published var selectedIndex: Int = 0
    @Published var searchText: String = "" { didSet { updateFilteredCommands() } }
    @Published private(set) var filteredCommands: [Command] = []

    init() {
        filteredCommands = CommandsManager.shared.commands
    }

    private func updateFilteredCommands() {
        filteredCommands = CommandsManager.shared.filteredCommands(by: searchText)
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
        searchText = ""
        updateFilteredCommands()
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

            // 命令列表（最多显示 8 条）
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(coordinator.filteredCommands.prefix(PaletteConfig.maxVisibleItems).enumerated()), id: \.offset) { index, command in
                            CommandPaletteRow(
                                command: command,
                                index: index + 1,
                                isSelected: index == coordinator.selectedIndex,
                                searchText: coordinator.searchText
                            )
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                coordinator.execute(command)
                            }
                        }
                    }
                }
                .frame(maxHeight: CGFloat(PaletteConfig.maxVisibleItems) * 40)
                .onChange(of: coordinator.selectedIndex) { newIndex in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

            // 底部提示
            HStack {
                Text("↵ 执行")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("⌘+数字 快速执行")
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
        .frame(width: PaletteConfig.width)
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
    let index: Int
    let isSelected: Bool
    let searchText: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)

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
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
}
