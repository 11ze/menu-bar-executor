import Foundation

extension String {
    /// 将字符串截断到指定长度，添加省略后缀
    func truncated(to maxLength: Int, trailing: String = "...") -> String {
        count > maxLength ? String(prefix(maxLength)) + trailing : self
    }

    /// 如果字符串为空则返回 nil
    var nilIfEmpty: String? { isEmpty ? nil : self }

    /// 去除版本号的 "v" 或 "V" 前缀
    var cleanVersionString: String {
        hasPrefix("v") || hasPrefix("V") ? String(dropFirst()) : self
    }
}
