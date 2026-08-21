# 候选 C · CommandPaletteView 拆 PaletteListModel

来源：架构审查 2026-08-21（Worth exploring #2）。前置：候选 A（seam）、B（镜像直连）已落地。
目标：面板列表的 56 行零覆盖纯逻辑（组装 / 导航 / 相对编号）提纯为值类型模型，纳入测试；475 行文件拆三。行为零变。

## 决策记录（两轮拷问已定）

| 决策 | 结论 |
|---|---|
| 形状 | 纯 struct 快照 + `derive` 纯函数；PaletteCoordinator 仍是唯一 ObservableObject，`@Published private(set) var listModel` 整体替换。避开嵌套 ObservableObject 不触发刷新的坑 |
| 收编范围 | `buildPaletteItems` + `adjustSelectedIndex` + `moveUp/moveDown` + `relativeDisplayIndex` 全收进模型；执行副作用（execute / executeAutoCommands / reset / autoExecuteResults）留 coordinator |
| 文件 | 拆三：`PaletteListModel.swift`（PaletteItem + 模型 + derive）、`PaletteCoordinator.swift`（协调器 + AutoExecuteState + PaletteConfig）、`CommandPaletteView.swift`（主视图 + 行视图 + PreferenceKey） |
| 测试 | 全套语义钉子：组装（组头插入 / 编号连续 / 过滤后重排）、导航（空列表 / 越界回卷 / 跳组头找最近命令项 / moveUp/Down 边界）、相对编号（滚动窗口起点 / clamp）约 8 个 |

## 模型形状（实现裁量）

```swift
/// 面板列表快照：由 commands + searchText + groupOrder 派生，纯值类型
struct PaletteListModel: Equatable {
    let items: [PaletteItem]
    let selectedIndex: Int
    let firstVisibleIndex: Int

    /// 搜索 / 命令变化时派生新列表，选中索引从 previousIndex 回绕调整（复刻现 adjustSelectedIndex 语义）
    static func derive(commands: [Command], searchText: String, groupOrder: [String]?,
                       previousIndex: Int, previousFirstVisibleIndex: Int) -> PaletteListModel

    /// 滚动回写：仅更新可见窗口起点
    func updatingFirstVisibleIndex(_ index: Int) -> PaletteListModel

    /// 相对快捷键编号（1 = 可见窗口内第一个命令项，复刻现 :335-346 语义）
    func relativeDisplayIndex(forAbsolute absolute: Int) -> Int

    /// 纯导航：跳过组头，出界返回 nil（coordinator 不更新）
    func movedUp() -> PaletteListModel?
    func movedDown() -> PaletteListModel?
}
```

- coordinator 触发面收敛为 `rebuild()`：searchText didSet、$commands sink、refreshCommands 三路都调它
- firstVisibleIndex 回写走 `updatingFirstVisibleIndex`（guard 不等才替换，等价现 :283-290）
- searchText 保持 `@Published`（TextField 绑定不动）
- 搜索路径的双写现状（didSet 里 adjust + 视图 onChange 重置到第一个命令项，后者覆盖前者）**保持不变**，标记待清理，不顺手合并

## 实施步骤（TDD 红绿）

1. 新建 `Tests/PaletteListModelTests.swift`：derive 组装钉子（组头插入 / 编号连续 / 过滤后重排）→ 红
2. 新建 `Sources/App/PaletteListModel.swift`（PaletteItem 迁入 + struct + derive，逻辑自 coordinator :92-143 平移）→ `xcodegen generate` → 绿
3. 导航钉子：derive 回绕边界（空列表 / 越界回卷 / 跳组头）+ movedUp/movedDown 边界 → 红 → 实现 → 绿
4. 相对编号钉子：relativeDisplayIndex（窗口起点 / clamp / 默认 1）+ updatingFirstVisibleIndex → 红 → 绿
5. coordinator 改造：删五个迁出方法，`@Published var listModel` 替换 paletteItems / selectedIndex / firstVisibleIndex，三路触发收敛 rebuild()；CommandPaletteView 改读 `coordinator.listModel.*`（onChange(of:) 改盯 `listModel.selectedIndex`）→ 构建
6. 拆文件：PaletteCoordinator.swift（coordinator + AutoExecuteState + PaletteConfig 迁出）→ `xcodegen generate` → 构建
7. 全量测试 + 构建冒烟（pkill → build /tmp → open）
8. 文档同步：architecture.md 项目结构三文件 + 单例关系图 PaletteCoordinator 描述

## 人工冒烟清单（实施后）

呼出面板搜索执行；↑↓ 导航跳组头、搜索后选中重置第一项；⌘+数字相对编号随滚动变化；自动执行命令的状态行（执行中 / 成功 / 失败）；外部改 settings.json 后重开面板。

## 已知行为变化（审查确认，非等价平移）

1. **相对编号越界保护**：旧实现在列表收缩、旧滚动位置未回写时会构造非法 Range 直接崩溃（如 `10..<3`）；新实现 derive 时夹回界内 + 计算时越界回退默认起点 1（测试 `testRelativeDisplayIndex_FirstVisibleBeyondBounds_FallsBackToDefaultOne` 钉住）。
2. **面板打开后选中自动落首命令项**：旧 `updatePaletteItems` 的 guard 只比 items，items 未变时不做选中调整——首项为组头的配置下，面板打开后选中停在组头索引 0、直接回车无反应。新 `rebuild` 的 guard 比较整个模型，同场景下 derive 把选中推进到首个命令项、回车执行第一条命令（语义由 `testDerive_EmptySearch_GroupsOrderedWithContinuousIndex` 钉住）。
3. **$commands sink 改用入参**：根治 willSet 阶段回读属性拿旧值的存量怪癖（原靠面板 onAppear 强制刷新补偿）。

## 范围外

- executeAutoCommands 结果管理（留 coordinator 原样）
- CommandPaletteRow 视觉结构（不动）
- 窗口控制器样板去重（候选 D）
- 搜索选中双路径合并（上述待清理项）

## 验证

```bash
xcodebuild test -project menu-bar-executor.xcodeproj \
  -scheme MenuBarExecutorTests -destination 'platform=macOS' \
  -derivedDataPath /tmp/menu-bar-executor-build
# 冒烟：pkill -f MenuBarExecutor → 构建到 /tmp → open
```

## 未解决问题

无。
