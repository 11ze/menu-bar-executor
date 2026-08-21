# 开发规范

- **单例**: `@MainActor` + `static let shared`，视图用 `@ObservedObject`（非 `@StateObject`）
- **Command 主键**: UUID（非 name），内部 `internal(set)` 允许修复重复 ID
- **配置写入**: 外部只读 `settings`，写入走 intent 方法（`setLaunchAtLogin` / `setDefaultInputSource` / `touchUpdateCheckDate` / `setSkippedVersion` / `saveCommands` / `updatePaletteFrame`），`save()` 私有；原子写入（`.tmp` 中转 + `replaceItem`）+ 回滚保护（`isLoaded` 标志防止空值覆盖）
- **文件监听**: `DispatchSource.makeFileSystemObjectSource` 监听 `.write`；自身写入走原子替换（rename）不产生 `.write` 事件，无需跳过标志，0.3s 防抖；`AppSettingsManager` 可注入文件路径测试（`init(filePath:enableFileMonitoring:notifyLoadError:)`，测试关通知防泄漏系统弹窗），`shared` 走 `AppPaths`
- **配置迁移**: 旧格式迁移（echo 分隔符假分组、重复 UUID）收口在 `AppSettings.migrateIfNeeded(_:)` 纯函数，`load()` / `importSettings(from:)` 统一调用
- **命令镜像**: `CommandsManager.commands` 唯一来源是 `$settings.map(\.commands).removeDuplicates()` 直连；外部修改/导入/重载都走这条链，勿新增同步链或通知中转（settingsDidReload 通知已删除）
- **面板**: `NSPanel`（无标题栏，透明背景）+ SwiftUI `windowBackgroundColor` 实色圆角背景 + `PaletteContainerView` 拦截键盘事件
- **面板列表**: 列表派生（组装 / 选中调整 / 相对编号 / 导航）收在 `PaletteListModel` 纯值类型，`derive` 快照整体替换；`PaletteCoordinator` 只留执行副作用，勿在 coordinator 或视图里加列表组装逻辑
- **键盘监听**: 本地 keyDown 监听一律用 `KeyDownMonitor`（start/stop 幂等，deinit 自动移除），勿手写 `addLocalMonitorForEvents` 四件套；窗口控制器在 show 时 start、willClose/hide 时 stop
- **Dock 隐藏**: `LSUIElement = true`
- **分组**: Command 的 `group` 字段，`groupOrder` 控制显示顺序；支持从旧版 "echo 分隔符" 自动迁移
- **执行**: `CommandExecutor` 是唯一执行入口；`ExecutionMode` 决定副作用——userInitiated 落历史 + 按 `notification` 发通知，auto 两者皆无；结果三态 `ExecutionResult`（成功 / 非零退出 / 没跑起来）
