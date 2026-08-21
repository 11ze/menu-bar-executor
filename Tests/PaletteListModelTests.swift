import XCTest
@testable import MenuBarExecutor

/// PaletteListModel（面板列表快照）派生 / 导航 / 相对编号的语义钉子
/// 语义复刻自 PaletteCoordinator 原 buildPaletteItems / adjustSelectedIndex / moveUp / moveDown / relativeDisplayIndex
final class PaletteListModelTests: XCTestCase {

    private func makeCommand(_ name: String, group: String? = nil) -> Command {
        Command(name: name, command: name, group: group)
    }

    /// 全量命令：u1(无组) b(B组) a(A组) u2(无组)，配合 groupOrder [A组, B组]
    private func makeAllCommands() -> [Command] {
        [makeCommand("u1"), makeCommand("b", group: "B组"), makeCommand("a", group: "A组"), makeCommand("u2")]
    }

    /// 把列表项压成可读串，避开 UUID 干扰断言
    private func summarize(_ items: [PaletteItem]) -> [String] {
        items.map {
            switch $0 {
            case .groupHeader(let name): return "h:\(name)"
            case .command(let cmd, let index): return "c:\(cmd.name):\(index)"
            }
        }
    }

    private func makeModel(items: [PaletteItem], selectedIndex: Int, firstVisibleIndex: Int) -> PaletteListModel {
        PaletteListModel(items: items, selectedIndex: selectedIndex, firstVisibleIndex: firstVisibleIndex)
    }

    // MARK: - derive 组装

    func testDerive_EmptySearch_GroupsOrderedWithContinuousIndex() {
        let model = PaletteListModel.derive(
            commands: makeAllCommands(), searchText: "", groupOrder: ["A组", "B组"],
            previousIndex: 0, previousFirstVisibleIndex: 0)

        // groupOrder 优先、无组殿后、组内保持原顺序、编号全列表连续
        XCTAssertEqual(summarize(model.items), ["h:A组", "c:a:1", "h:B组", "c:b:2", "c:u1:3", "c:u2:4"])
        // 选中从组头跳到其后第一个命令项
        XCTAssertEqual(model.selectedIndex, 1)
    }

    func testDerive_SearchFilter_ReindexesFromOne() {
        let model = PaletteListModel.derive(
            commands: makeAllCommands(), searchText: "u", groupOrder: ["A组", "B组"],
            previousIndex: 5, previousFirstVisibleIndex: 0)

        XCTAssertEqual(summarize(model.items), ["c:u1:1", "c:u2:2"])
        // previousIndex 越界回卷，从头找第一个命令项
        XCTAssertEqual(model.selectedIndex, 0)
    }

    func testDerive_SearchHitKeepsGroupHeader() {
        let model = PaletteListModel.derive(
            commands: makeAllCommands(), searchText: "a", groupOrder: ["A组", "B组"],
            previousIndex: 0, previousFirstVisibleIndex: 0)

        XCTAssertEqual(summarize(model.items), ["h:A组", "c:a:1"])
        XCTAssertEqual(model.selectedIndex, 1)
    }

    func testDerive_EmptyCommands_EmptyModel() {
        let model = PaletteListModel.derive(
            commands: [], searchText: "", groupOrder: nil,
            previousIndex: 3, previousFirstVisibleIndex: 7)

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertEqual(model.selectedIndex, 0)
        XCTAssertEqual(model.firstVisibleIndex, 0)
    }

    func testDerive_SelectedIndexOnGroupHeader_AdvancesToNextCommand() {
        // 上一选中落在组头上（列表收缩后常见），调整到其后第一个命令项
        let commands = [makeCommand("c1"), makeCommand("a1", group: "A组")]
        let model = PaletteListModel.derive(
            commands: commands, searchText: "", groupOrder: nil,
            previousIndex: 1, previousFirstVisibleIndex: 0)

        XCTAssertEqual(summarize(model.items), ["c:c1:1", "h:A组", "c:a1:2"])
        XCTAssertEqual(model.selectedIndex, 2)
    }

    func testDerive_ShrunkList_ClampsFirstVisibleIndex() {
        // 列表收缩后旧窗口位置夹回界内（防越界 Range）
        let model = PaletteListModel.derive(
            commands: [makeCommand("only")], searchText: "", groupOrder: nil,
            previousIndex: 0, previousFirstVisibleIndex: 9)

        XCTAssertEqual(model.firstVisibleIndex, 0)
    }

    // MARK: - 导航

    func testMovedUp_SkipsGroupHeadersAndStopsAtTop() {
        let items: [PaletteItem] = [
            .groupHeader("A组"),
            .command(makeCommand("a"), displayIndex: 1),
            .command(makeCommand("b"), displayIndex: 2),
        ]

        XCTAssertEqual(makeModel(items: items, selectedIndex: 2, firstVisibleIndex: 0).movedUp()?.selectedIndex, 1)
        // 顶上是组头，再向上无处可去
        XCTAssertNil(makeModel(items: items, selectedIndex: 1, firstVisibleIndex: 0).movedUp())
    }

    func testMovedDown_NilAtBottom() {
        let items: [PaletteItem] = [
            .groupHeader("A组"),
            .command(makeCommand("a"), displayIndex: 1),
        ]

        XCTAssertNil(makeModel(items: items, selectedIndex: 1, firstVisibleIndex: 0).movedDown())
    }

    // MARK: - 相对编号

    /// items: h:A, a(1), b(2), c(3)（index 0-3）
    private func makeNumberedModel(firstVisibleIndex: Int) -> PaletteListModel {
        let items: [PaletteItem] = [
            .groupHeader("A组"),
            .command(makeCommand("a"), displayIndex: 1),
            .command(makeCommand("b"), displayIndex: 2),
            .command(makeCommand("c"), displayIndex: 3),
        ]
        return makeModel(items: items, selectedIndex: 1, firstVisibleIndex: firstVisibleIndex)
    }

    func testRelativeDisplayIndex_WindowStartsAtFirstVisibleCommand() {
        // 窗口起点是组头，从其后第一个命令起算
        let model = makeNumberedModel(firstVisibleIndex: 0)
        XCTAssertEqual(model.relativeDisplayIndex(forAbsolute: 1), 1)
        XCTAssertEqual(model.relativeDisplayIndex(forAbsolute: 3), 3)

        // 滚动到 b 成为窗口首项
        let scrolled = makeNumberedModel(firstVisibleIndex: 2)
        XCTAssertEqual(scrolled.relativeDisplayIndex(forAbsolute: 2), 1)
        XCTAssertEqual(scrolled.relativeDisplayIndex(forAbsolute: 3), 2)
        // 窗口之前的命令被夹到 1
        XCTAssertEqual(scrolled.relativeDisplayIndex(forAbsolute: 1), 1)
    }

    func testRelativeDisplayIndex_FirstVisibleBeyondBounds_FallsBackToDefaultOne() {
        // 旧实现在此处会构造非法 Range 崩溃；钉住安全边界：越界回退默认起点 1
        let model = makeNumberedModel(firstVisibleIndex: 9)
        XCTAssertEqual(model.relativeDisplayIndex(forAbsolute: 1), 1)
        XCTAssertEqual(model.relativeDisplayIndex(forAbsolute: 3), 3)
    }

    func testUpdatingFirstVisibleIndex_OnlyChangesThatField() {
        let items: [PaletteItem] = [.command(makeCommand("a"), displayIndex: 1)]
        let model = makeModel(items: items, selectedIndex: 0, firstVisibleIndex: 0)

        let updated = model.updatingFirstVisibleIndex(3)
        XCTAssertEqual(updated.firstVisibleIndex, 3)
        XCTAssertEqual(updated.selectedIndex, 0)
        XCTAssertEqual(updated.items, model.items)
    }
}
