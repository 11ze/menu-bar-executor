# MenuBarExecutor

macOS 菜单栏命令执行器 —— 通过命令面板快速执行自定义 Shell 命令。

```
  全局快捷键 → 弹出面板 → 搜索/选择 → 执行 → 搞定
```

## 技术栈

| 层面       | 技术                                                    |
|------------|---------------------------------------------------------|
| 语言       | Swift 5.9+                                              |
| UI 框架    | SwiftUI + AppKit (NSPanel, NSStatusItem)                |
| 项目管理   | XcodeGen (`project.yml`)                                |
| 依赖       | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 2.0+ |
| 命令执行   | `Process` (zsh -i -l -c, 30s 超时)                     |
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
  ├── settings.json  ←→  AppSettingsManager (CRUD + 原子写入 + 文件监听)
  └── history.json   ←→  ExecutionHistory   (追加读写, 最近 100 条)
          │
          │  NotificationCenter (.settingsDidReload)
          ▼
  ┌─────────────────────────────────────────────────────────┐
  │  AppSettingsManager ──publish──▶ CommandsManager         │
  │                                         │               │
  │          CommandsManager ──▶ CommandExecutor ──▶ Process │
  │                                    │                    │
  │                                    ├─▶ NotificationMgr  │
  │                                    └─▶ ExecutionHistory │
  └─────────────────────────────────────────────────────────┘
          │
          ▼
  PaletteCoordinator ← CommandsManager.$commands (Combine)
       │
       └── CommandPaletteView   CommandsListView   HistoryView
```

## 命令执行流程

```
  用户按 Enter / ⌘+N
          │
          ▼
  PaletteCoordinator.execute(command)
          │
          ▼
  CommandExecutor.shared.execute(command)
          │
          ▼
  Process(/bin/zsh -i -l -c "<cmd>")  ← 30s 超时自动终止
          │
          ▼
  completion(success, output)
      │           │
      ▼           ▼
  面板内联     ExecutionHistory.add(record)
  显示结果          │
                    ▼
              NotificationManager (可选, 系统通知)
```

## 项目结构

```
Sources/App/
├── MenuBarExecutorApp.swift              # @main 入口
├── AppDelegate.swift                     # 菜单栏 + 快捷键 + 辅助功能权限
│
├── Command.swift                         # 命令模型 (UUID, Codable)
├── AppSettings.swift                     # 配置结构 + AppSettingsManager 单例
├── CommandsManager.swift                 # 命令列表管理 (CRUD + 执行调度)
├── CommandExecutor.swift                 # Shell 执行器 (Process + 超时)
├── ExecutionHistory.swift                # 执行历史 (最近 100 条)
├── NotificationManager.swift             # 系统通知
│
├── CommandPaletteView.swift              # 命令面板 SwiftUI 视图 + PaletteCoordinator
├── CommandPaletteWindowController.swift  # 面板窗口 (NSPanel + 毛玻璃)
├── HighlightedText.swift                 # 搜索高亮组件
│
├── Views/
│   ├── CommandsListView.swift            # 设置窗口: 命令列表 + 导入导出 + 拖拽排序
│   ├── CommandEditorView.swift           # 设置窗口: 单条命令编辑器
│   └── HistoryView.swift                 # 历史窗口: 执行记录列表
│
├── SettingsWindowController.swift        # 设置窗口控制器
├── HistoryWindowController.swift         # 历史窗口控制器
├── InputSourceHelper.swift               # 输入法切换 (Carbon TIS)
├── LaunchAtLoginManager.swift            # 开机自启 (macOS 13+ SMAppService)
├── UpdateManager.swift                   # GitHub Release 更新检查
├── UpdateInfo.swift                      # 版本信息模型
│
├── AppError.swift                        # 错误类型枚举
├── AppPaths.swift                        # 统一路径管理
└── StringExtensions.swift                # 字符串工具

Tests/
├── AppErrorTests.swift
├── AppSettingsTests.swift
├── CommandTests.swift
├── ExecutionRecordTests.swift
├── HighlightedTextRangeTests.swift
├── StringExtensionsTests.swift
└── UpdateInfoTests.swift

Scripts/
├── update_build_number.sh                # 自动更新构建号
├── create_icons.py                       # 创建图标
└── generate_appicon.py                   # 生成 AppIcon

project.yml                               # XcodeGen 项目定义
release.sh                                # 自动化发布 (版本号 + git tag + release notes)
```

## 单例关系

所有单例均为 `@MainActor` + `static let shared`，视图通过 `@ObservedObject` 引用。

```
AppSettingsManager.shared ──── 核心配置
    │
    ├── CommandsManager.shared ──── 命令列表
    │       │
    │       └── CommandExecutor.shared ── 命令执行
    │               │
    │               ├── NotificationManager.shared
    │               └── ExecutionHistory.shared
    │
    ├── PaletteCoordinator.shared ── 面板状态
    ├── LaunchAtLoginManager.shared ── 开机自启
    ├── UpdateManager.shared ── 版本更新
    │
    ├── CommandPaletteWindowController.shared ── 面板窗口
    ├── SettingsWindowController.shared ── 设置窗口
    └── HistoryWindowController.shared ── 历史窗口
```

## 配置文件

```
~/.config/menu-bar-executor/
├── settings.json     ← 主配置 (命令列表 + 面板位置/尺寸 + 启动项 + 输入法)
└── history.json      ← 执行历史 (最近 100 条)
```

settings.json 完整字段见 README.md。

## 开发规范

- **单例**: `@MainActor` + `static let shared`，视图用 `@ObservedObject`（非 `@StateObject`）
- **Command 主键**: UUID（非 name），内部 `internal(set)` 允许修复重复 ID
- **配置写入**: 原子写入（`write(.atomic)` + `replaceItem`）+ 回滚保护（`isLoaded` 标志防止空值覆盖）
- **文件监听**: `DispatchSource.makeFileSystemObjectSource`，自身写入通过 `skipNextFileChange` 跳过，0.3s 防抖
- **面板**: `NSPanel`（无标题栏）+ `NSVisualEffectView` 毛玻璃 + `PaletteContainerView` 拦截键盘事件
- **Dock 隐藏**: `LSUIElement = true`
- **分组**: Command 的 `group` 字段，`groupOrder` 控制显示顺序；支持从旧版 "echo 分隔符" 自动迁移

## 构建

```bash
# 生成 Xcode 项目
xcodegen generate

# Debug 构建
# 注意：构建到 /tmp 而非 ./build，因为项目位于 iCloud 同步路径下，
# iCloud 注入的扩展属性会导致 codesign 失败（见 release.sh 同理）。
xcodebuild -project menu-bar-executor.xcodeproj \
  -scheme MenuBarExecutor \
  -configuration Debug \
  -derivedDataPath /tmp/menu-bar-executor-build build

# 运行测试
xcodebuild test -project menu-bar-executor.xcodeproj \
  -scheme MenuBarExecutorTests \
  -destination 'platform=macOS'

# 快速重建+重启（日常开发）
pkill -f MenuBarExecutor; \
xcodebuild -project menu-bar-executor.xcodeproj \
  -scheme MenuBarExecutor \
  -derivedDataPath /tmp/menu-bar-executor-build build && \
open /tmp/menu-bar-executor-build/Build/Products/Debug/MenuBarExecutor.app
```
