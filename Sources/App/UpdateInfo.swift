import Foundation

/// 版本更新信息
struct UpdateInfo {
    /// 当前版本号
    let currentVersion: String

    /// 最新版本号
    let latestVersion: String

    /// GitHub Release 页面链接
    let releaseURL: URL

    /// 更新说明
    let releaseNotes: String?

    /// 是否有新版本
    var hasUpdate: Bool {
        Self.compareVersions(currentVersion, latestVersion) == .orderedAscending
    }
}

// MARK: - 版本比较

extension UpdateInfo {
    /// 比较两个 SemVer 版本号
    /// - Returns: .orderedAscending 如果 v1 < v2
    static func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let parts1 = parseVersion(v1)
        let parts2 = parseVersion(v2)

        if parts1.major != parts2.major {
            return parts1.major < parts2.major ? .orderedAscending : .orderedDescending
        }
        if parts1.minor != parts2.minor {
            return parts1.minor < parts2.minor ? .orderedAscending : .orderedDescending
        }
        if parts1.patch != parts2.patch {
            return parts1.patch < parts2.patch ? .orderedAscending : .orderedDescending
        }
        return .orderedSame
    }

    /// 解析 SemVer 版本号
    /// - Parameter version: 版本字符串，如 "1.2.3" 或 "v1.2.3"
    /// - Returns: (major, minor, patch) 元组
    static func parseVersion(_ version: String) -> (major: Int, minor: Int, patch: Int) {
        let cleanVersion = version.cleanVersionString
        let parts = cleanVersion.split(separator: ".").map { Int($0) ?? 0 }
        let major = parts.count > 0 ? parts[0] : 0
        let minor = parts.count > 1 ? parts[1] : 0
        let patch = parts.count > 2 ? parts[2] : 0

        return (major, minor, patch)
    }
}