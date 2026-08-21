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
