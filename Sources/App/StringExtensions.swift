import Foundation

extension String {
    /// 将字符串截断到指定长度，添加省略后缀
    func truncated(to maxLength: Int, trailing: String = "...") -> String {
        count > maxLength ? String(prefix(maxLength)) + trailing : self
    }

    /// 如果字符串为空则返回 nil
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
