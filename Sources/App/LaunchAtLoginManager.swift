import ServiceManagement

@MainActor
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    /// 是否支持自启动功能（macOS 13+）
    let isSupported: Bool

    /// 当前是否启用自启动
    var isEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    @available(macOS 13.0, *)
    nonisolated static func needsSystemCall(for enabled: Bool, currentStatus: SMAppService.Status) -> Bool {
        if enabled {
            return currentStatus != .enabled
        }
        return currentStatus != .notRegistered && currentStatus != .notFound
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else { return }
        guard Self.needsSystemCall(for: enabled, currentStatus: SMAppService.mainApp.status) else { return }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
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