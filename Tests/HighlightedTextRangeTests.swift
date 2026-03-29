import XCTest
@testable import MenuBarExecutor

final class HighlightedTextRangeTests: XCTestCase {

    func testSingleMatch() {
        let ranges = "Hello World".ranges(of: "World")
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(String("Hello World"[ranges[0]]), "World")
    }

    func testMultipleMatches() {
        let ranges = "aaa".ranges(of: "a")
        XCTAssertEqual(ranges.count, 3)
    }

    func testNoMatch() {
        let ranges = "Hello".ranges(of: "xyz")
        XCTAssertTrue(ranges.isEmpty)
    }

    func testEmptySearch() {
        let ranges = "Hello".ranges(of: "")
        XCTAssertTrue(ranges.isEmpty)
    }

    func testCaseInsensitive() {
        let ranges = "Hello hello HELLO".ranges(of: "hello", options: .caseInsensitive)
        XCTAssertEqual(ranges.count, 3)
    }

    func testCaseSensitive() {
        let ranges = "Hello hello".ranges(of: "Hello")
        XCTAssertEqual(ranges.count, 1)
    }

    func testOverlappingMatches() {
        let ranges = "aaa".ranges(of: "aa")
        XCTAssertEqual(ranges.count, 1)
    }

    func testMatchAtEnd() {
        let ranges = "abcxyz".ranges(of: "xyz")
        XCTAssertEqual(ranges.count, 1)
        let match = "abcxyz"[ranges[0]]
        XCTAssertEqual(String(match), "xyz")
    }

    func testSingleCharacter() {
        let ranges = "a".ranges(of: "a")
        XCTAssertEqual(ranges.count, 1)
    }

    func testMultipleWords() {
        let ranges = "foo bar foo baz foo".ranges(of: "foo")
        XCTAssertEqual(ranges.count, 3)
    }

    func testChineseCharacters() {
        let ranges = "命令面板 面板命令".ranges(of: "面板")
        XCTAssertEqual(ranges.count, 2)
    }
}
