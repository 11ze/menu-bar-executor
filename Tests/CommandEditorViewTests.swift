import XCTest
@testable import MenuBarExecutor

@MainActor
final class CommandEditorViewTests: XCTestCase {
    func testExistingCommandWithEmptyNameRemainsEditableAndDeletable() {
        let command = Command(name: "", command: "true")
        let editor = CommandEditorView(command: command, onSave: { _ in }, onDelete: {})
        XCTAssertTrue(editor.isExisting, "名称为空的已有命令仍应显示编辑与删除入口")
    }

    func testNewCommandDoesNotExposeDeletion() {
        let editor = CommandEditorView(command: nil, onSave: { _ in })
        XCTAssertFalse(editor.isExisting)
    }
}
