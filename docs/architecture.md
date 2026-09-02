# 架构与数据流

## 技术栈

| 层面       | 技术                                                    |
|------------|---------------------------------------------------------|
| 语言       | Swift 5.9+                                              |
| UI 框架    | SwiftUI + AppKit (NSPanel, NSStatusItem)                |
| 依赖       | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 2.0+ |
| 命令执行   | `Process`（30s 超时）                                    |
| 通知       | UserNotifications + NSAlert                              |
| 测试       | XCTest                                                  |

## 架构总览

```
                          ┌──────────────────┐
                          │  MenuBarExecutor  │  ← @main, SwiftUI App
                          │      App          │
                          └────────┬─────────┘
                                   │ @NSApplicationDelegateAdaptor
                          ┌────────▼─────────┐
                          │   AppDelegate     │  ← 菜单栏图标 + 全局快捷键
                          └────────┬─────────┘
                                   │
               ┌───────────────────┼───────────────────┐
               │                   │                   │
    ┌──────────▼──────┐ ┌─────────▼──────────┐ ┌──────▼──────────┐
    │ CommandPalette   │ │    Settings        │ │    History       │
    │ WindowController │ │ WindowController   │ │ WindowController │
    └────────┬────────┘ └─────────┬──────────┘ └──────┬──────────┘
             │                    │                    │
    ┌────────▼────────┐ ┌────────▼────────┐ ┌────────▼────────┐
    │ CommandPalette   │ │ CommandsList     │ │  HistoryView    │
    │ View + Coord.    │ │ + CommandEditor  │ │                 │
    └─────────────────┘ └──────────────────┘ └─────────────────┘
```

## 数据流

```
  ~/.config/menu-bar-executor/
  ├── settings.json  ←→  AppSettingsManager (intent 写入 + 原子写入 + 文件监听)
  └── history.json   ←→  ExecutionHistory   (追加读写, 最近 100 条)
          │
          │  Combine $settings 直连（无通知中转）
          ▼
  ┌─────────────────────────────────────────────────────────┐
  │  AppSettingsManager ──publish──▶ CommandsManager (镜像) │
  │                                                         │
  │  PaletteCoordinator ──▶ CommandExecutor ──▶ Process      │
  │                              │                          │
  │                              ├─▶ ExecutionHistory       │
  │                              └─▶ NotificationManager    │
  └─────────────────────────────────────────────────────────┘
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

## 项目结构

```
Sources/App/
├── MenuBarExecutorApp.swift              # @main 入口
├── AppDelegate.swift                     # 菜单栏 + 快捷键 + 辅助功能权限
│
├── Command.swift                         # 命令模型 (UUID, Codable)
├── AppSettings.swift                     # 配置结构 + 迁移纯函数 + AppSettingsManager 单例 (intent 写入收口, 可注入路径测试)
├── CommandsManager.swift                 # 命令视图适配层 (镜像从 $settings 直连派生, 写入直通)
├── CommandExecutor.swift                 # Shell 执行器 (Process + 超时 + ExecutionMode/ExecutionResult + 历史/通知副作用)
├── ExecutionHistory.swift                # 执行历史 (最近 100 条)
├── NotificationManager.swift             # 系统通知
│
├── PaletteListModel.swift                 # 面板列表快照 (纯值类型, derive/导航/相对编号可测)
├── PaletteCoordinator.swift               # 面板协调器 (列表派生在 PaletteListModel, 只留执行副作用)
├── CommandPaletteView.swift               # 命令面板 SwiftUI 视图 + 行视图
├── CommandPaletteWindowController.swift   # 面板窗口 (NSPanel + 毛玻璃)
├── HighlightedText.swift                 # 搜索高亮组件
│
├── Views/
│   ├── CommandsListView.swift            # 设置窗口: 命令列表 + 导入导出 + 拖拽排序
│   ├── CommandEditorView.swift           # 设置窗口: 单条命令编辑器
│   └── HistoryView.swift                 # 历史窗口: 执行记录列表
│
├── SettingsWindowController.swift        # 设置窗口控制器
├── HistoryWindowController.swift         # 历史窗口控制器
├── KeyDownMonitor.swift                  # 键盘事件监听生命周期 (start/stop 幂等, 三窗口共用)
├── InputSourceHelper.swift               # 输入法切换 (Carbon TIS)
├── LaunchAtLoginManager.swift            # 开机自启适配 (macOS 13+ SMAppService 纯系统状态)
├── UpdateManager.swift                   # GitHub Release 更新检查
├── UpdateInfo.swift                      # 版本信息模型
│
├── AppError.swift                        # 错误类型枚举
├── AppPaths.swift                        # 统一路径管理
└── StringExtensions.swift                # 字符串工具

Tests/
├── AppErrorTests.swift
├── AppSettingsTests.swift
├── AppSettingsManagerTests.swift
├── CommandExecutorTests.swift
├── CommandTests.swift
├── CommandsManagerTests.swift
├── ExecutionRecordTests.swift
├── HighlightedTextRangeTests.swift
├── KeyDownMonitorTests.swift
├── PaletteListModelTests.swift
├── StringExtensionsTests.swift
└── UpdateInfoTests.swift

Resources/
├── Assets.xcassets                       # App 图标
├── commands.json                         # 随包资源
└── Info.plist

scripts/
├── update_build_number.sh                # 自动更新构建号
├── create_icons.py                       # 创建图标
└── generate_appicon.py                   # 生成 AppIcon

docs/                                     # 架构、规范、plans
project.yml                               # XcodeGen 项目定义
release.sh                                # 自动化发布 (版本号 + git tag + release notes)
```

## 配置文件

```
~/.config/menu-bar-executor/
├── settings.json     ← 主配置 (命令列表 + 面板位置/尺寸 + 启动项 + 输入法)
└── history.json      ← 执行历史 (最近 100 条)
```

settings.json 完整字段见 README.md。
