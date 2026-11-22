import XCTest
@testable import MenuBarExecutor

@MainActor
final class CommandEditorViewTests: XCTestCase {
    func testExistingCommandWithEmptyNameRemainsEditableAndDeletable() {
        let command = Command(name: "", command: "true")
        let editor = CommandEditorView(command: command, onSave: { _ in true }, onDelete: { true })
        XCTAssertTrue(editor.isExisting, "名称为空的已有命令仍应显示编辑与删除入口")
    }

    func testSavingPreservesShellWhitespace() throws {
        let command = Command(name: "保留空白", command: "\n  printf '%s' foo\\ ")
        var saved: Command?
        let editor = CommandEditorView(command: command, onSave: { saved = $0; return true })

        editor.saveCommand()

        XCTAssertEqual(try XCTUnwrap(saved).command, "\n  printf '%s' foo\\ ",
                       "保存必须保留命令原文，末尾转义空格属于 Shell 语法")
    }

    func testSaveReportsFailureAndResubmitsSameCommand() {
        let command = Command(name: "重试", command: "printf test")
        var attempts: [Command] = []
        let editor = CommandEditorView(command: command, onSave: {
            attempts.append($0)
            return attempts.count > 1
        })
        XCTAssertFalse(editor.saveCommand())
        XCTAssertTrue(editor.saveCommand())
        XCTAssertEqual(attempts.map(\.command), ["printf test", "printf test"])
        XCTAssertEqual(attempts.map(\.id), [command.id, command.id])
    }

    func testNewCommandDoesNotExposeDeletion() {
        let editor = CommandEditorView(command: nil, onSave: { _ in true })
        XCTAssertFalse(editor.isExisting)
    }

    func testSavingTrimsGroupWhitespaceAndConvertsBlankToNil() throws {
        var savedTrimmed: Command?
        let trimmedEditor = CommandEditorView(
            command: Command(name: "带空格组", command: "true", group: "  开发工具  "),
            onSave: { savedTrimmed = $0; return true }
        )
        trimmedEditor.saveCommand()
        XCTAssertEqual(try XCTUnwrap(savedTrimmed).group, "开发工具")

        var savedBlank: Command?
        let blankEditor = CommandEditorView(
            command: Command(name: "纯空格组", command: "true", group: "   \n "),
            onSave: { savedBlank = $0; return true }
        )
        blankEditor.saveCommand()
        XCTAssertNil(try XCTUnwrap(savedBlank).group)
    }
}
