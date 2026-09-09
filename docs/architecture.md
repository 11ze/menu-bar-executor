# 架构与数据流

技术栈：Swift 5.9+ / SwiftUI + AppKit，依赖 [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)（SPM），测试 XCTest。

## 数据流

```
  ~/.config/menu-bar-executor/
  ├── settings.json  ←→  AppSettingsManager (intent 写入 + 原子写入 + 文件监听)
  └── history.json   ←→  ExecutionHistory   (追加读写, 最近 100 条)
          │
          │  Combine $settings 直连（无通知中转）
          ▼
  AppSettingsManager ──publish──▶ CommandsManager (镜像)
          │
          ▼
  PaletteCoordinator ← CommandsManager.$commands (Combine)
       │
       └── CommandPaletteView   CommandsListView   HistoryView
```

## 命令执行流程

```
  用户按 Enter / ⌘+N               打开面板 ⚡ 自动执行
          │                                  │
          ▼                                  ▼
  PaletteCoordinator.execute     PaletteCoordinator.executeAutoCommands
          │ (面板隐藏后立即)                  │
          └─────────────┬────────────────────┘
                        ▼
  CommandExecutor.shared.execute(command, mode:)
                        │
                        ▼
  launchArguments(for:) 按命令选择 shell 模式：
    默认       Process(/bin/zsh -i -l -c "<cmd>")  ← 30s 超时自动终止
    直接执行   Process(/bin/zsh -c "<cmd>")         ← 跳过 zshrc 加载, 10ms 级启动
                        │
                        ▼
  ExecutionResult（成功 / 非零退出 / 没跑起来）
       │                          │
       ▼                          ▼
  completion 回调              副作用（仅 userInitiated）：
  （auto 结果内联面板显示）     ExecutionHistory 落账 + 通知（按 command.notification）
```

## 单例关系

```
AppSettingsManager.shared ──── 核心配置
    │
    ├── CommandsManager.shared ──── 命令视图适配层
    │
    ├── CommandExecutor.shared ──── 命令执行 (Process + 超时 + 历史/通知副作用)
    │       │
    │       ├── NotificationManager.shared
    │       └── ExecutionHistory.shared
    │
    ├── PaletteCoordinator.shared ── 面板执行协调 (列表派生在 PaletteListModel 纯函数)
    ├── LaunchAtLoginManager.shared ── 开机自启
    ├── UpdateManager.shared ── 版本更新
    │
    ├── CommandPaletteWindowController.shared ── 面板窗口
    ├── SettingsWindowController.shared ── 设置窗口
    └── HistoryWindowController.shared ── 历史窗口
```

