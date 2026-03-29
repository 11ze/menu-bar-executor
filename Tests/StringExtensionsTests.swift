import XCTest
@testable import MenuBarExecutor

final class StringExtensionsTests: XCTestCase {

    // MARK: - truncated(to:trailing:)

    func testTruncated_LongString() {
        let result = "Hello World".truncated(to: 5)
        XCTAssertEqual(result, "Hello...")
    }

    func testTruncated_ShortString() {
        let result = "Hi".truncated(to: 10)
        XCTAssertEqual(result, "Hi")
    }

    func testTruncated_ExactLength() {
        let result = "Hello".truncated(to: 5)
        XCTAssertEqual(result, "Hello")
    }

    func testTruncated_EmptyString() {
        let result = "".truncated(to: 5)
        XCTAssertEqual(result, "")
    }

    func testTruncated_CustomTrailing() {
        let result = "Hello World".truncated(to: 5, trailing: "....")
        XCTAssertEqual(result, "Hello....")
    }

    func testTruncated_OneOverMaxLength() {
        let result = "123456".truncated(to: 5)
        XCTAssertEqual(result, "12345...")
    }

    // MARK: - nilIfEmpty

    func testNilIfEmpty_NonEmpty() {
        let result = "hello".nilIfEmpty
        XCTAssertEqual(result, "hello")
    }

    func testNilIfEmpty_Empty() {
        let result = "".nilIfEmpty
        XCTAssertNil(result)
    }

    func testNilIfEmpty_Whitespace() {
        let result = " ".nilIfEmpty
        XCTAssertEqual(result, " ")
    }

    // MARK: - cleanVersionString

    func testCleanVersionString_NoPrefix() {
        let result = "1.2.3".cleanVersionString
        XCTAssertEqual(result, "1.2.3")
    }

    func testCleanVersionString_LowerV() {
        let result = "v1.2.3".cleanVersionString
        XCTAssertEqual(result, "1.2.3")
    }

    func testCleanVersionString_UpperV() {
        let result = "V1.2.3".cleanVersionString
        XCTAssertEqual(result, "1.2.3")
    }

    func testCleanVersionString_JustV() {
        let result = "v".cleanVersionString
        XCTAssertEqual(result, "")
    }

    func testCleanVersionString_DoubleV() {
        let result = "vV1.2.3".cleanVersionString
        XCTAssertEqual(result, "V1.2.3")
    }

    func testCleanVersionString_Empty() {
        let result = "".cleanVersionString
        XCTAssertEqual(result, "")
    }
}
