import AppKit

/// 键盘事件监听生命周期：start/stop 幂等，deinit 自动移除
@MainActor
final class KeyDownMonitor {
    private var monitor: Any?
    private let handler: (NSEvent) -> NSEvent?

    init(handler: @escaping (NSEvent) -> NSEvent?) {
        self.handler = handler
    }

    var isActive: Bool { monitor != nil }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [handler] event in
            handler(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
