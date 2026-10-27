# 开发规范

- **配置写入**: 外部只读 `settings`，写入走 intent 方法（`setLaunchAtLogin` / `setAutoCheckUpdates` / `setDefaultInputSource` / `touchUpdateCheckDate` / `setSkippedVersion` / `saveCommands` / `updatePaletteFrame`），`save()` 私有
- **错误上报**: 启动/后台加载失败走系统通知（无窗口在场），窗口内操作（导入/导出）失败走 `lastError` → 视图 alert；`AppError` 只建模窗口内操作错误，加载错误直传通知不建 case
- **文件监听**: 外部修改 `settings.json` 靠文件监听同步进内存，intent 方法不读盘，内存即真相；自身写入触发的重载读回相同内容后自然吸收，勿加跳过标志
- **命令镜像**: `CommandsManager.commands` 唯一来源是 `$settings.map(\.commands).removeDuplicates()` 直连，勿新增同步链或通知中转
- **命令写入**: 新建/编辑统一走 `CommandsManager.upsert`（按 id 原位替换、未知追加），勿在视图闭包里自行判别身份
- **面板列表**: 列表派生收在 `PaletteListModel` 纯值类型，`PaletteCoordinator` 只留执行副作用，勿在 coordinator 或视图里加列表组装逻辑
- **面板配置快照**: `PaletteCoordinator` 从同一次 `$settings` 发布中取 `commands` 与 `groupOrder`，两者任一变化都重建列表；订阅内勿回读 `settings` 属性，避免 `willSet` 期间混用新旧值
- **面板自动执行**: `reset()` 与新一轮自动执行均使旧轮次回调失效，只接纳当前轮次结果；已启动的进程继续运行，仍经 `CommandExecutor` 的 auto 模式执行
- **键盘监听**: 本地 keyDown 监听一律用 `KeyDownMonitor`；有 marked text 时优先交给输入法，不抢候选确认或导航；勿手写 `addLocalMonitorForEvents` 四件套
- **执行**: `CommandExecutor` 是唯一执行入口；`ExecutionMode` 决定副作用——userInitiated 落历史 + 按 `notification` 发通知，auto 两者皆无；副作用 sink（`ExecutionHistoryRecording` / `ExecutionNotifying`）注入，测试接内存假件；`ProcessRunner` 先读管道再等退出，勿改回先等后读（大输出会互等死锁）

- **面板快捷键**: ⌘1–9 固定对应当前搜索结果前九条，滚动不改编号；搜索、选择和列表滚动无动画。鼠标只在实际移动时同步选择，不抢搜索焦点。
- **结果查看**: 自动执行结果浮层只读，不调用执行入口、不落历史；浮层和编辑 sheet 的键盘事件优先于面板导航与执行，取消删除保留编辑草稿。
- **历史展示**: 只展示已持久化的信息；现有输出最多 500 字符，不标注完整输出，不补造耗时、退出码或运行中状态。
- **更新开关**: `autoCheckUpdates` 缺失默认开启，只控制自动检查；延迟等待后与发通知前重新读取状态，手动检查保持可用。

- **面板内容**: 列表直接衔接底栏，不显示命令内容、工作目录或编辑入口；查看与编辑统一走设置页，空列表保留添加入口。
- **面板尺寸**: 默认按内容取高度；已有尺寸或手动调整后尊重保存高度，搜索不覆盖用户尺寸。原生窗口最小、最大高度必须保留可调整范围；尺寸写入仍走 `updatePaletteFrame`。
- **设置标签**: plain 按钮的留白参与点击，用内容形状明确命中区域。
- **输入法选项**: 仅按显示名称排除 `&` 和 `.`，不按 ID 过滤；通用页打开时刷新列表，过滤不改写已有输入法设置。

- **编辑身份**: 删除入口由调用方提供的删除能力决定，不以名称是否为空判断新建或已有命令；空名称的导入记录仍可编辑、删除。
