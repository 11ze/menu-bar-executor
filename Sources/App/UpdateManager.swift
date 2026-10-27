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
private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
    }
}

// MARK: - UpdateManager

/// 版本更新检查管理器
@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    /// 是否正在检查更新
    @Published private(set) var isChecking = false

    /// 上次检查的错误
    @Published private(set) var lastError: UpdateError?

    /// 在飞的检查任务：后来的调用（典型：启动自动检查在飞时用户手动点「检查更新」）
    /// 合流等它拿同一份网络结果，而不是早退 nil——早退会被调用方误读成「已是最新版本」
    private var inFlightCheck: Task<UpdateInfo?, Never>?

    private let settingsManager = AppSettingsManager.shared
    private let notificationManager = NotificationManager.shared

    private init() {}

    // MARK: - 公开方法

    /// 检查是否有新版本
    /// - Parameter force: 是否强制检查（忽略时间间隔）
    /// - Returns: 更新信息，如果没有新版本则返回 nil
    ///
    /// 手工验证合流（无测试注入点）：断网启动 → 2 秒内点「检查更新」→
    /// 弹「检查更新失败」而非「已是最新版本」即通过
    func checkForUpdate(force: Bool = false) async -> UpdateInfo? {
        if let inFlight = inFlightCheck {
            return await inFlight.value
        }
        let task = Task { await performCheck(force: force) }
        inFlightCheck = task
        defer { inFlightCheck = nil }
        return await task.value
    }

    private func performCheck(force: Bool) async -> UpdateInfo? {
        // 检查时间间隔
        if !force, let lastCheck = settingsManager.settings.lastUpdateCheckDate {
            let elapsed = Date().timeIntervalSince(lastCheck)
            if elapsed < UpdateConfig.minCheckInterval {
                return nil
            }
        }

        isChecking = true
        if lastError != nil {
            lastError = nil
        }
        defer { isChecking = false }

        do {
            let release = try await fetchLatestRelease()
            let currentVersion = getCurrentVersion()
            let latestVersion = release.tagName.cleanVersionString

            let updateInfo = UpdateInfo(
                currentVersion: currentVersion,
                latestVersion: latestVersion,
                releaseURL: release.htmlURL,
                releaseNotes: release.body
            )

            // 更新检查时间（只在成功时保存）
            settingsManager.touchUpdateCheckDate()

            // 检查是否跳过该版本
            if let skipped = settingsManager.settings.skippedVersion,
               skipped == latestVersion {
                return nil
            }

            return updateInfo.hasUpdate ? updateInfo : nil

        } catch {
            lastError = error as? UpdateError ?? .networkError(error)
            return nil
        }
    }

    /// 获取当前版本号
    /// - Returns: 从 Info.plist 读取的版本号
    func getCurrentVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
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
    private func fetchLatestRelease() async throws -> GitHubRelease {
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
            guard let updateInfo = await checkForUpdate(),
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