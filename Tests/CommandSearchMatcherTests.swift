import XCTest
@testable import MenuBarExecutor

final class CommandSearchMatcherTests: XCTestCase {

    private func highlightedPieces(in text: String, query: String) -> [String] {
        CommandSearchMatcher.matchRanges(in: text, query: query).map { String(text[$0]) }
    }

    func testEmptyOrWhitespaceQueryMatchesWithNoHighlightRanges() {
        XCTAssertTrue(CommandSearchMatcher.matches("启动 Docker 服务", query: ""))
        XCTAssertTrue(CommandSearchMatcher.matches("启动 Docker 服务", query: "   "))
        XCTAssertEqual(highlightedPieces(in: "启动 Docker 服务", query: ""), [])
        XCTAssertEqual(highlightedPieces(in: "启动 Docker 服务", query: "   "), [])
    }

    func testDirectCaseInsensitiveSubstringPreferredAndHighlighted() {
        XCTAssertTrue(CommandSearchMatcher.matches("启动 Docker 服务", query: "docker"))
        XCTAssertEqual(highlightedPieces(in: "启动 Docker 服务", query: "docker"), ["Docker"])
        XCTAssertEqual(highlightedPieces(in: "命令面板 面板命令", query: "面板"), ["面板", "面板"])
    }

    func testPinyinInitialsMatchChineseCommandNamesAndHighlightMatchedChars() {
        XCTAssertTrue(CommandSearchMatcher.matches("启动 Docker 服务", query: "qd"))
        XCTAssertEqual(highlightedPieces(in: "启动 Docker 服务", query: "qd"), ["启动"])

        XCTAssertTrue(CommandSearchMatcher.matches("刷新 DNS 缓存", query: "sxhc"))
        XCTAssertEqual(highlightedPieces(in: "刷新 DNS 缓存", query: "sxhc"), ["刷新", "缓存"])
    }

    func testFullPinyinAndMixedEnglishPinyinMatch() {
        XCTAssertTrue(CommandSearchMatcher.matches("启动 Docker 服务", query: "qidong"))
        XCTAssertEqual(highlightedPieces(in: "启动 Docker 服务", query: "qidong"), ["启动"])

        XCTAssertTrue(CommandSearchMatcher.matches("查看 Git 分支", query: "gitfz"))
        XCTAssertEqual(highlightedPieces(in: "查看 Git 分支", query: "gitfz"), ["Git", "分支"])

        XCTAssertTrue(CommandSearchMatcher.matches("刷新 DNS 缓存", query: "sx dns"))
        XCTAssertEqual(highlightedPieces(in: "刷新 DNS 缓存", query: "sx dns"), ["刷新", "DNS"])

        XCTAssertTrue(CommandSearchMatcher.matches("启动 Docker 服务", query: "qddocker"))
        XCTAssertEqual(highlightedPieces(in: "启动 Docker 服务", query: "qddocker"), ["启动", "Docker"])
    }

    func testEnglishSubsequenceMatch() {
        XCTAssertTrue(CommandSearchMatcher.matches("启动 Docker 服务", query: "dckr"))
        XCTAssertEqual(highlightedPieces(in: "启动 Docker 服务", query: "dckr"), ["D", "ck", "r"])
    }

    func testDoesNotFalseMatchUnrelatedTermsFromCommandBodyOrGroup() {
        let sampleNames = [
            "当前 IP 地址",
            "查看 Git 分支",
            "启动 Docker 服务",
            "启动本地开发环境",
            "清理 Xcode 缓存",
            "显示隐藏文件",
            "刷新 DNS 缓存",
            "打开下载文件夹",
        ]
        for name in sampleNames {
            XCTAssertFalse(CommandSearchMatcher.matches(name, query: "compose"), "不应误匹配命令正文词 compose: \(name)")
            XCTAssertFalse(CommandSearchMatcher.matches(name, query: "开发工具"), "不应误匹配分组名: \(name)")
        }
    }
}
