import ServiceManagement

@MainActor
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    /// 是否支持自启动功能（macOS 13+）
    let isSupported: Bool

    /// 当前是否启用自启动
    var isEnabled: Bool {
        get {
            guard #available(macOS 13.0, *) else { return false }
            return SMAppService.mainApp.status == .enabled
        }
        set {
            guard #available(macOS 13.0, *) else { return }
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }

    private init() {
        if #available(macOS 13.0, *) {
            isSupported = true
        } else {
            isSupported = false
        }
    }

    /// 同步配置与系统实际状态
    /// 当配置与系统状态不一致时，以系统状态为准
    func sync(withSettings enabled: Bool) {
        let systemState = isEnabled
        if enabled != systemState {
            // 以系统状态为准，更新配置
            AppSettingsManager.shared.settings.launchAtLogin = systemState
            AppSettingsManager.shared.save()
            CommandsManager.shared.launchAtLogin = systemState
        }
    }
}