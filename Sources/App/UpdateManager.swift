import AppKit
import Foundation

// MARK: - 更新配置

/// 更新检查配置
enum UpdateConfig {
    /// GitHub 仓库名称
    static let githubRepo = "11ze/menu-bar-executor"

    /// GitHub API 端点
    static var apiURL: URL {
        URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest")!
    }

    /// GitHub Releases 页面
    static var releasePageURL: URL {
        URL(string: "https://github.com/\(githubRepo)/releases/latest")!
    }

    /// 请求超时时间（秒）
    static let requestTimeout: TimeInterval = 15

    /// 最小检查间隔（秒），24 小时
    static let minCheckInterval: TimeInterval = 86400
}

// MARK: - GitHub Release 响应模型

/// GitHub Release API 响应
struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
    }
}

enum UpdateCheckResult {
    case available(UpdateInfo)
    case upToDate
    case skipped
    case failed(UpdateError)
}

// MARK: - UpdateManager

/// 版本更新检查管理器
@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    /// 是否正在检查更新
    @Published private(set) var isChecking = false

    /// 合流网络请求，每个调用方分别应用自动/手动检查规则。
    private var inFlightCheck: Task<Result<GitHubRelease, UpdateError>, Never>?

    private let settingsManager: AppSettingsManager
    private let currentVersion: String?
    private let fetchRelease: () async throws -> GitHubRelease
    private let notificationManager = NotificationManager.shared

    init(
        settingsManager: AppSettingsManager = .shared,
        currentVersion: String? = nil,
        fetchRelease: @escaping () async throws -> GitHubRelease = UpdateManager.fetchLatestRelease
    ) {
        self.settingsManager = settingsManager
        self.currentVersion = currentVersion
        self.fetchRelease = fetchRelease
    }

    // MARK: - 公开方法

    func checkForUpdate(force: Bool = false) async -> UpdateCheckResult {
        if !force, inFlightCheck == nil,
           let lastCheck = settingsManager.settings.lastUpdateCheckDate,
           Date().timeIntervalSince(lastCheck) < UpdateConfig.minCheckInterval {
            return .skipped
        }

        switch await fetchReleaseOnce() {
        case .success(let release):
            let latestVersion = release.tagName.cleanVersionString
            let info = UpdateInfo(currentVersion: getCurrentVersion(), latestVersion: latestVersion,
                                  releaseURL: release.htmlURL, releaseNotes: release.body)
            guard info.hasUpdate else { return .upToDate }
            if !force, settingsManager.settings.skippedVersion == latestVersion { return .skipped }
            return .available(info)
        case .failure(let error):
            return .failed(error)
        }
    }

    private func fetchReleaseOnce() async -> Result<GitHubRelease, UpdateError> {
        if let inFlightCheck { return await inFlightCheck.value }
        isChecking = true
        let task = Task { () -> Result<GitHubRelease, UpdateError> in
            do { return .success(try await fetchRelease()) }
            catch { return .failure(error as? UpdateError ?? .networkError(error)) }
        }
        inFlightCheck = task
        defer {
            inFlightCheck = nil
            isChecking = false
        }
        let result = await task.value
        if case .success = result { settingsManager.touchUpdateCheckDate() }
        return result
    }

    /// 获取当前版本号
    /// - Returns: 从 Info.plist 读取的版本号
    func getCurrentVersion() -> String {
        currentVersion ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// 打开 GitHub Releases 页面
    func openReleasePage() {
        NSWorkspace.shared.open(UpdateConfig.releasePageURL)
    }

    /// 跳过指定版本
    /// - Parameter version: 要跳过的版本号
    func skipVersion(_ version: String) {
        settingsManager.setSkippedVersion(version)
    }

    // MARK: - 私有方法

    /// 获取最新 Release 信息
    nonisolated private static func fetchLatestRelease() async throws -> GitHubRelease {
        var request = URLRequest(url: UpdateConfig.apiURL)
        request.timeoutInterval = UpdateConfig.requestTimeout
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UpdateError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }

        // 处理特定的 HTTP 状态码
        switch httpResponse.statusCode {
        case 200:
            break
        case 403:
            // API 限流
            throw UpdateError.apiRateLimited
        case 404:
            // 没有找到 release
            throw UpdateError.noReleaseFound
        default:
            throw UpdateError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw UpdateError.invalidResponse
        }
    }
}

// MARK: - 自动检查

extension UpdateManager {
    /// 执行自动检查（启动时调用）
    /// 延迟 2 秒后检查，避免阻塞启动
    func performAutoCheck() {
        guard settingsManager.settings.autoCheckUpdates else { return }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 秒

            guard settingsManager.settings.autoCheckUpdates else { return }
            guard case .available(let updateInfo) = await checkForUpdate(),
                  settingsManager.settings.autoCheckUpdates else { return }

            // 显示系统通知
            notificationManager.showUpdateAvailable(
                version: updateInfo.latestVersion,
                action: { [weak self] in
                    self?.openReleasePage()
                }
            )
        }
    }
}