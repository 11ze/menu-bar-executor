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

    func testFilteredCommands_MatchesPinyinInitialsAndMixedQuery() {
        let commands = [
            Command(name: "启动 Docker 服务", command: "open -a Docker", group: "开发工具"),
            Command(name: "查看 Git 分支", command: "git branch --show-current", group: "状态速览"),
            Command(name: "刷新 DNS 缓存", command: "sudo dscacheutil -flushcache", group: "日常操作"),
        ]
        XCTAssertEqual(CommandsManager.filteredCommands(from: commands, by: "qd").map(\.name), ["启动 Docker 服务"])
        XCTAssertEqual(CommandsManager.filteredCommands(from: commands, by: "gitfz").map(\.name), ["查看 Git 分支"])
        XCTAssertEqual(CommandsManager.filteredCommands(from: commands, by: "sx dns").map(\.name), ["刷新 DNS 缓存"])
    }

    // MARK: - duplicatingCommand

    func testDuplicatingCommand_InsertsAfterOriginalWithUniqueNameAndCopiesProperties() {
        let original = Command(
            name: "启动服务",
            command: "docker compose up -d",
            workingDirectory: "~/dev",
            notification: false,
            autoExecute: true,
            group: "开发工具",
            directExecution: true,
            hidden: true
        )
        let sibling = Command(name: "其他命令", command: "echo hi", group: "开发工具")

        let first = CommandsManager.duplicatingCommand(original.id, in: [original, sibling])
        XCTAssertEqual(first?.commands.map(\.name), ["启动服务", "启动服务 副本", "其他命令"])
        XCTAssertNotEqual(first?.duplicate.id, original.id)
        XCTAssertEqual(first?.duplicate.command, original.command)
        XCTAssertEqual(first?.duplicate.workingDirectory, original.workingDirectory)
        XCTAssertEqual(first?.duplicate.notification, original.notification)
        XCTAssertEqual(first?.duplicate.autoExecute, original.autoExecute)
        XCTAssertEqual(first?.duplicate.group, original.group)
        XCTAssertEqual(first?.duplicate.directExecution, original.directExecution)
        XCTAssertEqual(first?.duplicate.hidden, original.hidden)

        let second = CommandsManager.duplicatingCommand(original.id, in: first!.commands)
        XCTAssertEqual(second?.duplicate.name, "启动服务 副本 2")
        XCTAssertEqual(second?.commands.map(\.name), ["启动服务", "启动服务 副本 2", "启动服务 副本", "其他命令"])

        XCTAssertNil(CommandsManager.duplicatingCommand(UUID(), in: [original]))
    }

    // MARK: - 显隐控制

    func testVisibleCommands_ExcludesHiddenCommandsHiddenGroupsAndHiddenUngrouped() {
        let commands = [
            Command(name: "可见1", command: "1", group: "状态速览"),
            Command(name: "单条隐藏", command: "2", group: "状态速览", hidden: true),
            Command(name: "隐藏组内可见", command: "3", group: "运维排查"),
            Command(name: "隐藏组内也隐藏", command: "4", group: "运维排查", hidden: true),
            Command(name: "未分组可见", command: "5"),
            Command(name: "未分组隐藏", command: "6", hidden: true),
        ]

        let visibleWithUngrouped = CommandsManager.visibleCommands(
            from: commands,
            hiddenGroups: ["  运维排查  "],
            hideUngrouped: false
        )
        XCTAssertEqual(visibleWithUngrouped.map(\.name), ["可见1", "未分组可见"])

        let visibleWithoutUngrouped = CommandsManager.visibleCommands(
            from: commands,
            hiddenGroups: ["运维排查"],
            hideUngrouped: true
        )
        XCTAssertEqual(visibleWithoutUngrouped.map(\.name), ["可见1"])
    }

    func testSettingGroupHidden_NormalizesDeduplicatesAndToggles() {
        let added = CommandsManager.settingGroupHidden("  运维排查 ", hidden: true, in: ["开发工具", "运维排查"])
        XCTAssertEqual(added, ["开发工具", "运维排查"])

        let addedNew = CommandsManager.settingGroupHidden("状态速览", hidden: true, in: ["开发工具"])
        XCTAssertEqual(addedNew, ["开发工具", "状态速览"])

        let removed = CommandsManager.settingGroupHidden("运维排查", hidden: false, in: ["开发工具", "运维排查"])
        XCTAssertEqual(removed, ["开发工具"])
    }

    func testTogglingCommandHidden_FlipsTargetInPlace() {
        let first = Command(name: "a", command: "1", hidden: false)
        let second = Command(name: "b", command: "2", hidden: true)

        let toggledFirst = CommandsManager.togglingCommandHidden(first.id, in: [first, second])
        XCTAssertEqual(toggledFirst?.map(\.hidden), [true, true])

        let toggledSecond = CommandsManager.togglingCommandHidden(second.id, in: [first, second])
        XCTAssertEqual(toggledSecond?.map(\.hidden), [false, false])

        XCTAssertNil(CommandsManager.togglingCommandHidden(UUID(), in: [first, second]))
    }

    func testRenamingGroup_MigratesHiddenGroups() {
        let commands = [
            Command(name: "a1", command: "true", group: "运维排查"),
            Command(name: "b1", command: "true", group: "开发工具"),
        ]
        let renamed = CommandsManager.renamingGroup(
            "运维排查",
            to: "线上排查",
            in: commands,
            groupOrder: ["运维排查", "开发工具"],
            hiddenGroups: ["运维排查"]
        )
        XCTAssertEqual(renamed?.hiddenGroups, ["线上排查"])
        XCTAssertEqual(renamed?.groupOrder, ["线上排查", "开发工具"])
    }

    func testRenamingGroup_NormalizesWhitespaceInCommandsAndHiddenGroups() {
        let commands = [
            Command(name: "secret", command: "echo 1", autoExecute: true, group: "  Dev  "),
        ]
        let renamed = CommandsManager.renamingGroup(
            "Dev",
            to: "Tools",
            in: commands,
            groupOrder: nil,
            hiddenGroups: ["  Dev  "]
        )
        XCTAssertEqual(renamed?.commands.map(\.group), ["Tools"])
        XCTAssertEqual(renamed?.groupOrder, ["Tools"])
        XCTAssertEqual(renamed?.hiddenGroups, ["Tools"], "带首尾空白的命令分组与 hiddenGroups 在重命名后必须保持隐藏迁移")

        let visibleToOrphan = CommandsManager.renamingGroup(
            "Dev",
            to: "Ops",
            in: [Command(name: "a", command: "true", group: "Dev")],
            groupOrder: nil,
            hiddenGroups: ["Ops"]
        )
        XCTAssertEqual(visibleToOrphan?.hiddenGroups, [], "可见分组重命名为孤儿 hiddenGroups 名称后不得意外变为隐藏")
    }

    func testDissolvingGroup_NormalizesWhitespaceInCommandGroups() {
        let commands = [
            Command(name: "secret", command: "echo 1", autoExecute: true, group: "  Dev  "),
        ]
        let dissolved = CommandsManager.dissolvingGroup(
            "Dev",
            in: commands,
            groupOrder: nil,
            hiddenGroups: ["  Dev  "]
        )
        XCTAssertEqual(dissolved?.commands.map(\.group), [nil], "带首尾空白的命令分组解散后必须移入未分组")
        XCTAssertEqual(dissolved?.hiddenGroups, [])
    }

    func testPrunedHiddenGroups_RemovesOrphansWhenGroupNoLongerExists() {
        let commands = [Command(name: "a", command: "true", group: "保留")]
        let pruned = CommandsManager.prunedHiddenGroups(
            ["  保留  ", "已删空组", "已删空组"],
            commands: commands,
            groupOrder: nil
        )
        XCTAssertEqual(pruned, ["保留"])

        let keptEmptyInOrder = CommandsManager.prunedHiddenGroups(
            ["空命名组", "不存在"],
            commands: commands,
            groupOrder: ["空命名组", "保留"]
        )
        XCTAssertEqual(keptEmptyInOrder, ["空命名组"])
    }

    func testDissolvingGroup_RemovesFromHiddenGroupsAndPreservesCommandHiddenState() {
        let commands = [
            Command(name: "a1", command: "true", group: "运维排查", hidden: false),
            Command(name: "a2", command: "true", group: "运维排查", hidden: true),
            Command(name: "b1", command: "true", group: "开发工具", hidden: false),
        ]
        let dissolved = CommandsManager.dissolvingGroup(
            "运维排查",
            in: commands,
            groupOrder: ["运维排查", "开发工具"],
            hiddenGroups: ["运维排查", "开发工具"]
        )
        XCTAssertEqual(dissolved?.hiddenGroups, ["开发工具"])
        XCTAssertEqual(dissolved?.commands.map(\.group), [nil, nil, "开发工具"])
        XCTAssertEqual(dissolved?.commands.map(\.hidden), [false, true, false], "删除隐藏分组后应保留每条命令各自的显隐标记")
    }
}
