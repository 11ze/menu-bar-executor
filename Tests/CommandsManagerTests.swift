import XCTest
@testable import MenuBarExecutor

/// CommandsManager 纯函数（过滤 / 分组排序）的语义钉子
final class CommandsManagerTests: XCTestCase {

    private func makeCommands() -> [Command] {
        [
            Command(name: "u1", command: "u1"),
            Command(name: "b", command: "b", group: "B组"),
            Command(name: "a", command: "a", group: "A组"),
            Command(name: "u2", command: "u2"),
        ]
    }

    // MARK: - sortedGroupNames

    func testSortedGroupNames_GroupOrderTakesPrecedence() {
        let result = CommandsManager.sortedGroupNames(from: makeCommands(), groupOrder: ["A组", "幽灵组", "B组"])
        // groupOrder 里的组按其顺序优先，不存在的组被滤掉，未分组殿后
        XCTAssertEqual(result, ["A组", "B组", nil])
    }

    func testSortedGroupNames_NewGroupsFollowAppearanceOrder() {
        let commands = [
            Command(name: "x", command: "x", group: "新2"),
            Command(name: "y", command: "y", group: "已排"),
            Command(name: "z", command: "z", group: "新1"),
        ]
        // groupOrder 未覆盖的新组按命令列表首现序接在后面
        XCTAssertEqual(CommandsManager.sortedGroupNames(from: commands, groupOrder: ["已排"]), ["已排", "新2", "新1"])
    }

    func testSortedGroupNames_NoGroupOrder_KeepsAppearanceOrder() {
        XCTAssertEqual(CommandsManager.sortedGroupNames(from: makeCommands(), groupOrder: nil), [nil, "B组", "A组"])
    }

    // MARK: - upserted（新建 / 编辑的身份判别）

    func testUpserted_UnknownIdAppends() {
        let existing = Command(name: "a", command: "a")
        let fresh = Command(name: "b", command: "b")

        let result = CommandsManager.upserted(fresh, in: [existing])

        XCTAssertEqual(result.map(\.name), ["a", "b"])
    }

    func testUpserted_KnownIdReplacesInPlace() {
        let original = Command(name: "a", command: "a")
        let edited = Command(id: original.id, name: "a2", command: "a2")
        let other = Command(name: "z", command: "z")

        let result = CommandsManager.upserted(edited, in: [original, other])

        XCTAssertEqual(result.map(\.name), ["a2", "z"], "编辑保持原位置")
    }

    func testSortedGroupNames_DeduplicatesAndIgnoresEmptyGroupOrderEntries() {
        let commands = [
            Command(name: "empty", command: "true", group: ""),
            Command(name: "a", command: "true", group: "A组"),
            Command(name: "b", command: "true", group: "B组"),
        ]
        let dirtyOrder = ["", "A组", "A组", "B组"]

        XCTAssertEqual(CommandsManager.sortedGroupNames(from: commands, groupOrder: dirtyOrder), ["A组", "B组", nil])
    }

    // MARK: - 分组管理（含空分组、拖拽排序、新建、重命名、解散）

    func testManagedGroupNames_KeepsEmptyGroupsFromGroupOrderAndAppendsNewGroups() {
        let commands = [
            Command(name: "u1", command: "true"),
            Command(name: "b", command: "true", group: "B组"),
            Command(name: "c", command: "true", group: "C组"),
        ]
        let result = CommandsManager.managedGroupNames(from: commands, groupOrder: ["", "空组", "B组", "空组"])
        XCTAssertEqual(result, ["空组", "B组", "C组"])
    }

    func testMovingGroup_ReordersAcrossManagedGroups() {
        let commands = [
            Command(name: "a", command: "true", group: "A组"),
            Command(name: "b", command: "true", group: "B组"),
            Command(name: "c", command: "true", group: "C组"),
        ]
        XCTAssertEqual(
            CommandsManager.movingGroup("C组", to: "A组", from: commands, groupOrder: ["A组", "B组", "C组"]),
            ["C组", "A组", "B组"]
        )
        XCTAssertEqual(
            CommandsManager.movingGroup("A组", to: "C组", from: commands, groupOrder: ["A组", "B组", "C组"]),
            ["B组", "C组", "A组"]
        )
        XCTAssertNil(CommandsManager.movingGroup("A组", to: "A组", from: commands, groupOrder: ["A组", "B组"]))
        XCTAssertNil(CommandsManager.movingGroup("不存在", to: "A组", from: commands, groupOrder: ["A组", "B组"]))
    }

    func testManagedAndSortedGroupNames_IgnoreWhitespaceOnlyGroups() {
        let commands = [
            Command(name: "blank", command: "true", group: "   "),
            Command(name: "a", command: "true", group: "A组"),
        ]
        XCTAssertEqual(CommandsManager.managedGroupNames(from: commands, groupOrder: ["   ", "A组"]), ["A组"])
        XCTAssertEqual(CommandsManager.sortedGroupNames(from: commands, groupOrder: ["   ", "A组"]), ["A组", nil])
    }

    func testCanMoveCommand_ValidatesSameGroupWithoutReordering() {
        let c1 = Command(name: "a1", command: "1", group: "A组")
        let c2 = Command(name: "a2", command: "2", group: "A组")
        let b1 = Command(name: "b1", command: "3", group: "B组")
        let commands = [c1, c2, b1]

        XCTAssertTrue(CommandsManager.canMoveCommand(c1.id, to: c2.id, in: commands))
        XCTAssertFalse(CommandsManager.canMoveCommand(c1.id, to: c1.id, in: commands))
        XCTAssertFalse(CommandsManager.canMoveCommand(c1.id, to: b1.id, in: commands))
    }

    func testGroupOrderAfterUpserting_AppendsNewGroupWhenGroupOrderExists() {
        let existing = [Command(name: "a1", command: "1", group: "A组")]
        let fresh = Command(name: "b1", command: "2", group: "B组")

        XCTAssertEqual(
            CommandsManager.groupOrderAfterUpserting(fresh, in: existing, currentGroupOrder: ["A组"]),
            ["A组", "B组"]
        )
        XCTAssertNil(
            CommandsManager.groupOrderAfterUpserting(fresh, in: existing, currentGroupOrder: nil)
        )
    }

    func testAddingGroup_TrimsAndRejectsBlankOrDuplicate() {
        let commands = [Command(name: "a", command: "true", group: "A组")]
        XCTAssertEqual(CommandsManager.addingGroup("  新组  ", from: commands, groupOrder: nil), ["A组", "新组"])
        XCTAssertNil(CommandsManager.addingGroup("   ", from: commands, groupOrder: nil))
        XCTAssertNil(CommandsManager.addingGroup("A组", from: commands, groupOrder: nil))
        XCTAssertNil(CommandsManager.addingGroup("空组", from: commands, groupOrder: ["空组"]))
    }

    func testRenamingGroup_UpdatesCommandsAndGroupOrder() {
        let commands = [
            Command(name: "a1", command: "true", group: "A组"),
            Command(name: "b1", command: "true", group: "B组"),
            Command(name: "a2", command: "true", group: "A组"),
        ]
        let renamed = CommandsManager.renamingGroup("A组", to: "  核心  ", in: commands, groupOrder: ["A组", "B组"])
        XCTAssertEqual(renamed?.groupOrder, ["核心", "B组"])
        XCTAssertEqual(renamed?.commands.map(\.group), ["核心", "B组", "核心"])
        XCTAssertNil(CommandsManager.renamingGroup("A组", to: "   ", in: commands, groupOrder: ["A组", "B组"]))
        XCTAssertNil(CommandsManager.renamingGroup("A组", to: "A组", in: commands, groupOrder: ["A组", "B组"]))
        XCTAssertNil(CommandsManager.renamingGroup("A组", to: "B组", in: commands, groupOrder: ["A组", "B组"]))
    }

    func testDissolvingGroup_MovesCommandsToUngroupedAndRemovesFromGroupOrder() {
        let commands = [
            Command(name: "a1", command: "true", group: "A组"),
            Command(name: "b1", command: "true", group: "B组"),
            Command(name: "a2", command: "true", group: "A组"),
        ]
        let dissolved = CommandsManager.dissolvingGroup("A组", in: commands, groupOrder: ["A组", "B组"])
        XCTAssertEqual(dissolved?.groupOrder, ["B组"])
        XCTAssertEqual(dissolved?.commands.map(\.group), [nil, "B组", nil])
        XCTAssertNil(CommandsManager.dissolvingGroup("不存在", in: commands, groupOrder: ["A组", "B组"]))
    }

    // MARK: - 命令拖拽（组内重排 & 跨组归类）

    func testMovingCommand_ReordersWithinSameGroupAndRejectsCrossGroup() {
        let c1 = Command(name: "a1", command: "1", group: "A组")
        let other = Command(name: "b1", command: "2", group: "B组")
        let c2 = Command(name: "a2", command: "3", group: "A组")
        let c3 = Command(name: "a3", command: "4", group: "A组")
        let commands = [c1, other, c2, c3]

        let movedUp = CommandsManager.movingCommand(c3.id, to: c1.id, in: commands)
        XCTAssertEqual(movedUp?.filter { $0.group == "A组" }.map(\.name), ["a3", "a1", "a2"])

        let movedDown = CommandsManager.movingCommand(c1.id, to: c3.id, in: commands)
        XCTAssertEqual(movedDown?.filter { $0.group == "A组" }.map(\.name), ["a2", "a3", "a1"])

        XCTAssertNil(CommandsManager.movingCommand(c1.id, to: other.id, in: commands))
        XCTAssertNil(CommandsManager.movingCommand(c1.id, to: c1.id, in: commands))
    }

    func testAssigningCommandToGroup_UpdatesGroupAndAppendsToEnd() {
        let c1 = Command(name: "a1", command: "1", group: "A组")
        let c2 = Command(name: "b1", command: "2", group: "B组")
        let commands = [c1, c2]

        let toB = CommandsManager.assigningCommand(c1.id, toGroup: "B组", in: commands)
        XCTAssertEqual(toB?.map(\.name), ["b1", "a1"])
        XCTAssertEqual(toB?.last?.group, "B组")

        let toUngrouped = CommandsManager.assigningCommand(c1.id, toGroup: nil, in: commands)
        XCTAssertEqual(toUngrouped?.last?.name, "a1")
        XCTAssertNil(toUngrouped?.last?.group)

        XCTAssertNil(CommandsManager.assigningCommand(c1.id, toGroup: "A组", in: commands))
    }

    // MARK: - filteredCommands

    func testFilteredCommands_EmptySearchReturnsAll() {
        let commands = makeCommands()
        XCTAssertEqual(CommandsManager.filteredCommands(from: commands, by: ""), commands)
    }

    func testFilteredCommands_CaseInsensitiveNameMatch() {
        let result = CommandsManager.filteredCommands(from: makeCommands(), by: "U1")
        XCTAssertEqual(result.map(\.name), ["u1"])
    }
}
