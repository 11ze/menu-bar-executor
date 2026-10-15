# 开发规范

- **配置写入**: 外部只读 `settings`，写入走 intent 方法（`setLaunchAtLogin` / `setDefaultInputSource` / `touchUpdateCheckDate` / `setSkippedVersion` / `saveCommands` / `updatePaletteFrame`），`save()` 私有
- **文件监听**: 外部修改 `settings.json` 靠文件监听同步进内存，intent 方法不读盘，内存即真相；自身写入触发的重载读回相同内容后自然吸收，勿加跳过标志
- **命令镜像**: `CommandsManager.commands` 唯一来源是 `$settings.map(\.commands).removeDuplicates()` 直连，勿新增同步链或通知中转
- **面板列表**: 列表派生收在 `PaletteListModel` 纯值类型，`PaletteCoordinator` 只留执行副作用，勿在 coordinator 或视图里加列表组装逻辑
- **键盘监听**: 本地 keyDown 监听一律用 `KeyDownMonitor`，勿手写 `addLocalMonitorForEvents` 四件套
- **执行**: `CommandExecutor` 是唯一执行入口；`ExecutionMode` 决定副作用——userInitiated 落历史 + 按 `notification` 发通知，auto 两者皆无；`ProcessRunner` 先读管道再等退出，勿改回先等后读（大输出会互等死锁）
