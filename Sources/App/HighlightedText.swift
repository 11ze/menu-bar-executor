import SwiftUI

/// 高亮显示匹配文本的视图
struct HighlightedText: View {
    let text: String
    let search: String
    /// 命中片段的颜色；由调用方按所在行的底色给出，避免和行文字色冲突。
    let highlight: Color

    var body: some View {
        if search.isEmpty {
            Text(text)
        } else {
            highlightedText
        }
    }

    private var highlightedText: Text {
        let ranges = CommandSearchMatcher.matchRanges(in: text, query: search)
        var result = Text("")

        var currentIndex = text.startIndex

        for range in ranges {
            // 未匹配的前缀
            if currentIndex < range.lowerBound {
                let prefix = text[currentIndex..<range.lowerBound]
                result = result + Text(String(prefix))
            }

            // 高亮匹配部分
            let matched = text[range]
            result = result + Text(String(matched))
                .foregroundColor(highlight)
                .fontWeight(.medium)

            currentIndex = range.upperBound
        }

        // 未匹配的后缀
        if currentIndex < text.endIndex {
            let suffix = text[currentIndex..<text.endIndex]
            result = result + Text(String(suffix))
        }

        return result
    }
}

extension String {
    /// 查找所有匹配的范围
    func ranges(of substring: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        guard !substring.isEmpty else { return [] }

        var result: [Range<String.Index>] = []
        var startIndex = self.startIndex

        while startIndex < endIndex {
            guard let range = range(of: substring, options: options, range: startIndex..<endIndex) else {
                break
            }
            result.append(range)
            startIndex = range.upperBound
        }

        return result
    }
}