import XCTest
@testable import MenuBarExecutor

/// 面板列表派生、导航与固定快捷键编号。
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

    private func makeModel(items: [PaletteItem], selectedIndex: Int) -> PaletteListModel {
        PaletteListModel(items: items, selectedIndex: selectedIndex)
    }

    // MARK: - derive 组装

    func testDerive_EmptySearch_GroupsOrderedWithContinuousIndex() {
        let model = PaletteListModel.derive(
            commands: makeAllCommands(), searchText: "", groupOrder: ["A组", "B组"],
            previousIndex: 0)

        // groupOrder 优先、无组殿后、组内保持原顺序、编号全列表连续
        XCTAssertEqual(summarize(model.items), ["h:A组", "c:a:1", "h:B组", "c:b:2", "c:u1:3", "c:u2:4"])
        // 选中从组头跳到其后第一个命令项
        XCTAssertEqual(model.selectedIndex, 1)
    }

    func testDerive_SearchFilter_ReindexesFromOne() {
        let model = PaletteListModel.derive(
            commands: makeAllCommands(), searchText: "u", groupOrder: ["A组", "B组"],
            previousIndex: 5)

        XCTAssertEqual(summarize(model.items), ["c:u1:1", "c:u2:2"])
        // previousIndex 越界回卷，从头找第一个命令项
        XCTAssertEqual(model.selectedIndex, 0)
    }

    func testDerive_SearchHitKeepsGroupHeader() {
        let model = PaletteListModel.derive(
            commands: makeAllCommands(), searchText: "a", groupOrder: ["A组", "B组"],
            previousIndex: 0)

        XCTAssertEqual(summarize(model.items), ["h:A组", "c:a:1"])
        XCTAssertEqual(model.selectedIndex, 1)
    }

    func testDerive_EmptyCommands_EmptyModel() {
        let model = PaletteListModel.derive(
            commands: [], searchText: "", groupOrder: nil,
            previousIndex: 3)

        XCTAssertTrue(model.items.isEmpty)
        XCTAssertEqual(model.selectedIndex, 0)
    }

    func testDerive_SelectedIndexOnGroupHeader_AdvancesToNextCommand() {
        // 上一选中落在组头上（列表收缩后常见），调整到其后第一个命令项
        let commands = [makeCommand("c1"), makeCommand("a1", group: "A组")]
        let model = PaletteListModel.derive(
            commands: commands, searchText: "", groupOrder: nil,
            previousIndex: 1)

        XCTAssertEqual(summarize(model.items), ["c:c1:1", "h:A组", "c:a1:2"])
        XCTAssertEqual(model.selectedIndex, 2)
    }

    func testDerive_EmptyGroupRemainsVisibleWithoutOtherUngroupedCommands() {
        let commands = [makeCommand("空分组", group: ""), makeCommand("已分组", group: "A")]
        let model = PaletteListModel.derive(commands: commands, searchText: "", groupOrder: nil, previousIndex: 0)
        XCTAssertEqual(summarize(model.items), ["c:空分组:1", "h:A", "c:已分组:2"])
    }

    // MARK: - 导航

    func testMovedUp_SkipsGroupHeadersAndStopsAtTop() {
        let items: [PaletteItem] = [
            .groupHeader("A组"),
            .command(makeCommand("a"), displayIndex: 1),
            .command(makeCommand("b"), displayIndex: 2),
        ]

        XCTAssertEqual(makeModel(items: items, selectedIndex: 2).movedUp()?.selectedIndex, 1)
        // 顶上是组头，再向上无处可去
        XCTAssertNil(makeModel(items: items, selectedIndex: 1).movedUp())
    }

    func testMovedDown_NilAtBottom() {
        let items: [PaletteItem] = [
            .groupHeader("A组"),
            .command(makeCommand("a"), displayIndex: 1),
        ]

        XCTAssertNil(makeModel(items: items, selectedIndex: 1).movedDown())
    }

    // MARK: - 固定快捷键

    func testQuickSelect_SelectionDoesNotChangeShortcutTargets() {
        let commands = [makeCommand("a", group: "A"), makeCommand("b", group: "A"), makeCommand("c", group: "B")]
        let model = PaletteListModel.derive(commands: commands, searchText: "", groupOrder: nil, previousIndex: 0)
        let lastSelected = model.updatingSelectedIndex(4)
        XCTAssertEqual(lastSelected.command(atQuickSelectPosition: 1)?.name, "a")
        XCTAssertEqual(lastSelected.command(atQuickSelectPosition: 3)?.name, "c")
        XCTAssertNil(lastSelected.command(atQuickSelectPosition: 4))
    }

    func testQuickSelect_OnlyFirstNineCommandsAndSearchReindexes() {
        let commands = (1...10).map { makeCommand("命令 \($0)", group: "分组") }
        let model = PaletteListModel.derive(commands: commands, searchText: "", groupOrder: nil, previousIndex: 0)
        XCTAssertEqual(model.command(atQuickSelectPosition: 9)?.name, "命令 9")
        XCTAssertNil(model.command(atQuickSelectPosition: 10))
        XCTAssertNil(model.command(atQuickSelectPosition: 0))
        let filtered = PaletteListModel.derive(commands: commands, searchText: "10", groupOrder: nil, previousIndex: 0)
        XCTAssertEqual(filtered.command(atQuickSelectPosition: 1)?.name, "命令 10")
        XCTAssertNil(filtered.command(atQuickSelectPosition: 2))
    }
}
