import XCTest
@testable import MenuBarExecutor

@MainActor
final class CommandEditorViewTests: XCTestCase {
    func testExistingCommandWithEmptyNameRemainsEditableAndDeletable() {
        let command = Command(name: "", command: "true")
        let editor = CommandEditorView(command: command, onSave: { _ in }, onDelete: {})
        XCTAssertTrue(editor.isExisting, "名称为空的已有命令仍应显示编辑与删除入口")
    }

    func testSavingPreservesShellWhitespace() throws {
        let command = Command(name: "保留空白", command: "\n  printf '%s' foo\\ ")
        var saved: Command?
        let editor = CommandEditorView(command: command, onSave: { saved = $0 })

        editor.saveCommand()

        XCTAssertEqual(try XCTUnwrap(saved).command, "\n  printf '%s' foo\\ ",
                       "保存必须保留命令原文，末尾转义空格属于 Shell 语法")
    }

    func testNewCommandDoesNotExposeDeletion() {
        let editor = CommandEditorView(command: nil, onSave: { _ in })
        XCTAssertFalse(editor.isExisting)
    }
}
