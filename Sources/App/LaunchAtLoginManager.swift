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
}