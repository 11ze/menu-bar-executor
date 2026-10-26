# 开发规范

- **配置写入**: 外部只读 `settings`，写入走 intent 方法（`setLaunchAtLogin` / `setDefaultInputSource` / `touchUpdateCheckDate` / `setSkippedVersion` / `saveCommands` / `updatePaletteFrame`），`save()` 私有
- **错误上报**: 启动/后台加载失败走系统通知（无窗口在场），窗口内操作（导入/导出）失败走 `lastError` → 视图 alert；`AppError` 只建模窗口内操作错误，加载错误直传通知不建 case
- **文件监听**: 外部修改 `settings.json` 靠文件监听同步进内存，intent 方法不读盘，内存即真相；自身写入触发的重载读回相同内容后自然吸收，勿加跳过标志
- **命令镜像**: `CommandsManager.commands` 唯一来源是 `$settings.map(\.commands).removeDuplicates()` 直连，勿新增同步链或通知中转
- **命令写入**: 新建/编辑统一走 `CommandsManager.upsert`（按 id 原位替换、未知追加），勿在视图闭包里自行判别身份
- **面板列表**: 列表派生收在 `PaletteListModel` 纯值类型，`PaletteCoordinator` 只留执行副作用，勿在 coordinator 或视图里加列表组装逻辑
- **面板配置快照**: `PaletteCoordinator` 从同一次 `$settings` 发布中取 `commands` 与 `groupOrder`，两者任一变化都重建列表；订阅内勿回读 `settings` 属性，避免 `willSet` 期间混用新旧值
- **面板自动执行**: `reset()` 与新一轮自动执行均使旧轮次回调失效，只接纳当前轮次结果；已启动的进程继续运行，仍经 `CommandExecutor` 的 auto 模式执行
- **键盘监听**: 本地 keyDown 监听一律用 `KeyDownMonitor`，勿手写 `addLocalMonitorForEvents` 四件套
- **执行**: `CommandExecutor` 是唯一执行入口；`ExecutionMode` 决定副作用——userInitiated 落历史 + 按 `notification` 发通知，auto 两者皆无；副作用 sink（`ExecutionHistoryRecording` / `ExecutionNotifying`）注入，测试接内存假件；`ProcessRunner` 先读管道再等退出，勿改回先等后读（大输出会互等死锁）
