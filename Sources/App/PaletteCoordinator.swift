import Combine
import Foundation

// MARK: - 面板配置常量
enum PaletteConfig {
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
    /// 面板淡入时长
    static let fadeDuration: TimeInterval = 0.1
    /// 列表行内布局过渡时长（自动执行结果切换、导航滚动）
    static let rowTransitionDuration: TimeInterval = 0.15
}

// MARK: - 自动执行状态
enum AutoExecuteState: Equatable {
    case loading
    case success(String)
    case failure(String)
}

// MARK: - PaletteCoordinator
// 协调器：连接 NSView 键盘事件和 SwiftUI 状态；列表派生在 PaletteListModel，此处只留执行副作用
@MainActor
final class PaletteCoordinator: ObservableObject {
    static let shared = PaletteCoordinator(settingsManager: .shared)

    @Published var searchText: String = "" { didSet { refreshCommands() } }
    @Published private(set) var listModel: PaletteListModel
    @Published var autoExecuteResults: [UUID: AutoExecuteState] = [:]
    /// 键盘导航请求滚动的目标索引；hover 只改选中不发请求，避免滚动与 hover 互相触发
    @Published var scrollRequest: Int?

    private var cancellables = Set<AnyCancellable>()
    private let settingsManager: AppSettingsManager
    private let runAutoCommand: @MainActor (Command, @escaping @MainActor (ExecutionResult) -> Void) -> Void
    private var autoExecuteGeneration = 0

    init(
        settingsManager: AppSettingsManager,
        runAutoCommand: @escaping @MainActor (Command, @escaping @MainActor (ExecutionResult) -> Void) -> Void = { command, completion in
            CommandExecutor.shared.execute(command: command, mode: .auto, completion: completion)
        }
    ) {
        self.settingsManager = settingsManager
        self.runAutoCommand = runAutoCommand
        listModel = PaletteListModel.derive(
            commands: settingsManager.settings.commands,
            searchText: "",
            groupOrder: settingsManager.settings.groupOrder,
            previousIndex: 0,
            previousFirstVisibleIndex: 0
        )

        // commands 和 groupOrder 必须取自同一次发布，避免 willSet 期间回读旧属性。
        settingsManager.$settings
            .removeDuplicates { $0.commands == $1.commands && $0.groupOrder == $1.groupOrder }
            .sink { [weak self] settings in self?.rebuild(with: settings) }
            .store(in: &cancellables)
    }

    /// 触发收敛点：搜索变化 / 命令列表变化 / 面板呼出刷新都走这里；
    /// 配置发布时直接使用传入快照，不回读 settingsManager.settings
    private func rebuild(with settings: AppSettings) {
        let next = PaletteListModel.derive(
            commands: settings.commands,
            searchText: searchText,
            groupOrder: settings.groupOrder,
            previousIndex: listModel.selectedIndex,
            previousFirstVisibleIndex: listModel.firstVisibleIndex
        )
        guard next != listModel else { return }
        let selectedIndexChanged = next.selectedIndex != listModel.selectedIndex
        listModel = next
        // derive 类的选中变化（搜索收缩 / 外部重载）请求滚回可视区；hover 不走 rebuild，保持静默
        if selectedIndexChanged {
            scrollRequest = next.selectedIndex
        }
    }

    func refreshCommands() {
        rebuild(with: settingsManager.settings)
    }

    func updateFirstVisibleIndex(_ index: Int) {
        guard index != listModel.firstVisibleIndex else { return }
        listModel = listModel.updatingFirstVisibleIndex(index)
    }

    /// 搜索文本变化后由视图调用：重置到第一个命令项
    func selectFirstCommand() {
        guard let index = listModel.items.firstIndex(where: { $0.isCommand }) else { return }
        if index != listModel.selectedIndex {
            listModel = listModel.updatingSelectedIndex(index)
            scrollRequest = index
        }
    }

    /// 鼠标 hover 选中：只移动选中，不请求滚动
    func selectOnHover(_ index: Int) {
        guard index != listModel.selectedIndex,
              listModel.items.indices.contains(index),
              listModel.items[index].isCommand else { return }
        listModel = listModel.updatingSelectedIndex(index)
    }

    func moveUp() {
        if let next = listModel.movedUp() {
            listModel = next
            scrollRequest = next.selectedIndex
        }
    }

    func moveDown() {
        if let next = listModel.movedDown() {
            listModel = next
            scrollRequest = next.selectedIndex
        }
    }

    func execute(_ command: Command) {
        CommandPaletteWindowController.shared.hide()
        // hide() 同步返回无需等待；execute 内部 fork 后即返回，不阻塞主线程
        CommandExecutor.shared.execute(command: command, mode: .userInitiated)
    }

    func executeSelected() {
        guard listModel.selectedIndex < listModel.items.count,
              let cmd = listModel.items[listModel.selectedIndex].command else { return }
        execute(cmd)
    }

    func reset() {
        // 已发出的命令继续运行，旧轮次回调不得重新写入清空后的结果。
        autoExecuteGeneration += 1
        // 复刻原顺序：先清选中与窗口，再清搜索（触发 rebuild）
        listModel = PaletteListModel(items: listModel.items, selectedIndex: 0, firstVisibleIndex: 0)
        searchText = ""
        autoExecuteResults.removeAll()
        scrollRequest = nil
    }

    func executeAutoCommands() {
        autoExecuteGeneration += 1
        let generation = autoExecuteGeneration
        let autoCommands = listModel.items.compactMap { item -> Command? in
            guard case .command(let cmd, _) = item, cmd.autoExecute else { return nil }
            return cmd
        }
        guard !autoCommands.isEmpty else { return }

        for command in autoCommands {
            autoExecuteResults[command.id] = .loading

            runAutoCommand(command) { [weak self] result in
                guard let self, generation == self.autoExecuteGeneration else { return }
                switch result {
                case .success(let output):
                    let trimmed = output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    self.autoExecuteResults[command.id] = .success(trimmed)
                case .exitedAbnormally(_, let output):
                    let trimmed = output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    self.autoExecuteResults[command.id] = .failure(trimmed.isEmpty ? "执行失败" : trimmed)
                case .failed(let error):
                    self.autoExecuteResults[command.id] = .failure(error.localizedDescription)
                }
            }
        }
    }

    func clearSearch() {
        searchText = ""
    }
}
