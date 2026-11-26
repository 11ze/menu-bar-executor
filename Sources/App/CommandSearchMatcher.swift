import Foundation

/// 命令名称搜索匹配器：优先连续子串，其次支持中文拼音（全拼/简拼/混合）与英文子序列匹配。
/// 仅匹配传入文本本身，不扩展到命令原文或分组名。
enum CommandSearchMatcher {

    private struct Token {
        let range: Range<String.Index>
        let lowerChars: [Character]
        let pinyinChars: [Character]?
        let isWordBoundary: Bool
    }

    private struct MatchState {
        let score: Int
        let matchedIndices: [Int]
    }

    /// DP 匹配推进状态：区分尚未开始（前导跳过无惩罚）、刚命中（连续加分）与已开始但中断（紧凑惩罚）。
    private enum MatchMode: Int, CaseIterable {
        case idle = 0
        case adjacent = 1
        case gapped = 2
    }

    private static let pinyinLock = NSLock()
    private static var pinyinCache: [Character: [Character]] = [:]

    static func matches(_ text: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if text.range(of: trimmed, options: .caseInsensitive) != nil {
            return true
        }
        return !fuzzyRanges(in: text, query: trimmed).isEmpty
    }

    static func matchRanges(in text: String, query: String) -> [Range<String.Index>] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let direct = text.ranges(of: trimmed, options: .caseInsensitive)
        if !direct.isEmpty {
            return direct
        }
        return fuzzyRanges(in: text, query: trimmed)
    }

    // MARK: - 拼音与模糊匹配核心

    private static func fuzzyRanges(in text: String, query: String) -> [Range<String.Index>] {
        let queryChars = Array(query.lowercased().filter { !$0.isWhitespace })
        guard !queryChars.isEmpty else { return [] }

        let tokens = tokenize(text)
        guard !tokens.isEmpty else { return [] }

        let n = tokens.count
        let m = queryChars.count
        var memo = Array(
            repeating: Array(repeating: Array<MatchState??>(repeating: nil, count: MatchMode.allCases.count), count: m + 1),
            count: n + 1
        )

        func solve(_ i: Int, _ j: Int, _ mode: MatchMode) -> MatchState? {
            if j == m { return MatchState(score: 0, matchedIndices: []) }
            if i == n { return nil }
            if let cached = memo[i][j][mode.rawValue] { return cached }

            var best: MatchState?

            // 尝试匹配当前字符（直接字面匹配或汉字拼音前缀匹配）
            let token = tokens[i]
            let consumeOptions = matchOptions(for: token, queryChars: queryChars, from: j)
            for option in consumeOptions {
                guard let rest = solve(i + 1, j + option.length, .adjacent) else { continue }
                var score = rest.score + 10
                if option.isLiteral {
                    score += 12
                }
                if mode == .adjacent {
                    // 优先连续命中的字/字母（如 "qd" 优先命中相邻的「启动」而非「启」+「D」）
                    score += 28
                }
                if token.isWordBoundary {
                    score += 8
                }
                if let pinyin = token.pinyinChars, option.length == pinyin.count {
                    score += 6
                }
                // 靠前轻微加权，保证确定性
                score += max(0, 64 - i) / 16

                let candidate = MatchState(score: score, matchedIndices: [i] + rest.matchedIndices)
                if best == nil || candidate.score > best!.score {
                    best = candidate
                }
            }

            // 跳过当前字符：未开始匹配时免费，已开始匹配后每跳过一个字符扣分以保持结果紧凑
            let nextMode: MatchMode = mode == .idle ? .idle : .gapped
            if let skipped = solve(i + 1, j, nextMode) {
                let penalty = mode == .idle ? 0 : 4
                let candidate = MatchState(score: skipped.score - penalty, matchedIndices: skipped.matchedIndices)
                if best == nil || candidate.score > best!.score {
                    best = candidate
                }
            }

            memo[i][j][mode.rawValue] = best
            return best
        }

        guard let result = solve(0, 0, .idle), !result.matchedIndices.isEmpty else { return [] }
        return mergeRanges(indices: result.matchedIndices, tokens: tokens)
    }

    private static func matchOptions(
        for token: Token,
        queryChars: [Character],
        from j: Int
    ) -> [(length: Int, isLiteral: Bool)] {
        var options: [(length: Int, isLiteral: Bool)] = []
        let remaining = queryChars.count - j

        if !token.lowerChars.isEmpty, remaining >= token.lowerChars.count {
            var matched = true
            for k in 0..<token.lowerChars.count where queryChars[j + k] != token.lowerChars[k] {
                matched = false
                break
            }
            if matched {
                options.append((token.lowerChars.count, true))
            }
        }

        if let pinyin = token.pinyinChars, !pinyin.isEmpty {
            let maxLen = min(pinyin.count, remaining)
            var matchedPrefix = 0
            while matchedPrefix < maxLen && queryChars[j + matchedPrefix] == pinyin[matchedPrefix] {
                matchedPrefix += 1
            }
            if matchedPrefix > 0 {
                // 允许首字母或任意长度的连续前缀，优先尝试更长前缀
                for len in stride(from: matchedPrefix, through: 1, by: -1) where !options.contains(where: { $0.length == len }) {
                    options.append((len, false))
                }
            }
        }

        return options
    }

    private static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        tokens.reserveCapacity(text.count)
        var index = text.startIndex
        var prevWasSeparator = true

        while index < text.endIndex {
            let nextIndex = text.index(after: index)
            let char = text[index]
            let lowerChars = Array(String(char).lowercased())
            let pinyin = isCJK(char) ? pinyinCharacters(for: char) : nil
            let isBoundary = prevWasSeparator || pinyin != nil || char.isUppercase
            tokens.append(Token(
                range: index..<nextIndex,
                lowerChars: lowerChars,
                pinyinChars: pinyin,
                isWordBoundary: isBoundary
            ))
            prevWasSeparator = char.isWhitespace || char == "-" || char == "_" || char == "/" || char == "."
            index = nextIndex
        }
        return tokens
    }

    private static func mergeRanges(indices: [Int], tokens: [Token]) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        for idx in indices {
            let range = tokens[idx].range
            if let last = ranges.last, last.upperBound == range.lowerBound {
                ranges[ranges.count - 1] = last.lowerBound..<range.upperBound
            } else {
                ranges.append(range)
            }
        }
        return ranges
    }

    private static func isCJK(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }

    private static func pinyinCharacters(for character: Character) -> [Character]? {
        pinyinLock.lock()
        if let cached = pinyinCache[character] {
            pinyinLock.unlock()
            return cached.isEmpty ? nil : cached
        }
        pinyinLock.unlock()

        let mutable = NSMutableString(string: String(character)) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let ascii = (mutable as String)
            .lowercased()
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        let chars = Array(ascii)

        pinyinLock.lock()
        pinyinCache[character] = chars
        pinyinLock.unlock()
        return chars.isEmpty ? nil : chars
    }
}
