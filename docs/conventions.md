# 开发规范

- **单例**: `@MainActor` + `static let shared`，视图用 `@ObservedObject`（非 `@StateObject`）
- **Command 主键**: UUID（非 name），内部 `internal(set)` 允许修复重复 ID
- **配置写入**: 外部只读 `settings`，写入走 intent 方法（`setLaunchAtLogin` / `setDefaultInputSource` / `touchUpdateCheckDate` / `setSkippedVersion` / `saveCommands` / `updatePaletteFrame`），`save()` 私有；原子写入（`.tmp` 中转 + `replaceItem`）+ 回滚保护（`isLoaded` 标志防止空值覆盖）
- **文件监听**: `DispatchSource.makeFileSystemObjectSource` 监听 `.write`；自身写入走原子替换（rename）不产生 `.write` 事件，无需跳过标志，0.3s 防抖；`AppSettingsManager` 可注入文件路径测试（`init(filePath:enableFileMonitoring:)`），`shared` 走 `AppPaths`
- **配置迁移**: 旧格式迁移（echo 分隔符假分组、重复 UUID）收口在 `AppSettings.migrateIfNeeded(_:)` 纯函数，`load()` / `importSettings(from:)` 统一调用
- **面板**: `NSPanel`（无标题栏）+ `NSVisualEffectView` 毛玻璃 + `PaletteContainerView` 拦截键盘事件
- **Dock 隐藏**: `LSUIElement = true`
- **分组**: Command 的 `group` 字段，`groupOrder` 控制显示顺序；支持从旧版 "echo 分隔符" 自动迁移
- **执行**: `CommandExecutor` 是唯一执行入口；`ExecutionMode` 决定副作用——userInitiated 落历史 + 按 `notification` 发通知，auto 两者皆无；结果三态 `ExecutionResult`（成功 / 非零退出 / 没跑起来）
