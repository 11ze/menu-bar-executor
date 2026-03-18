# MenuBarExecutor

## 项目概述

macOS 菜单栏命令执行器，在菜单栏显示自定义命令，点击后执行并显示通知。支持图形界面命令设置、命令分组、快捷键绑定、命令搜索和执行历史功能。

## 技术栈

- Swift 5.9+, SwiftUI
- XcodeGen 项目管理
- UserNotifications 通知
- Process 执行 shell 命令
- XCTest 单元测试

## 项目结构

```
Sources/App/
├── MenuBarExecutorApp.swift      # SwiftUI App 入口
├── AppDelegate.swift             # App 代理，菜单栏管理
├── Command.swift                 # 命令模型（UUID 主键）
├── CommandExecutor.swift         # Shell 命令执行器（30 秒超时）
├── CommandsManager.swift         # 命令设置器（CRUD + 回滚）
├── ConfigLoader.swift            # 配置文件加载器（原子写入）
├── NotificationManager.swift     # 通知管理器
├── ExecutionHistory.swift        # 执行历史管理（最近 100 条）
├── HistoryWindowController.swift # 历史窗口控制器
├── SettingsWindowController.swift # 设置窗口控制器
├── AppError.swift                # 错误类型定义
├── AppPaths.swift                # 统一路径管理
├── StringExtensions.swift        # 字符串扩展工具
└── Views/
    ├── CommandsListView.swift    # 命令列表视图（搜索 + 分组标签）
    ├── CommandEditorView.swift   # 命令编辑器（分组 + 快捷键）
    └── HistoryView.swift         # 执行历史视图

Tests/
├── CommandTests.swift            # Command 模型测试
└── ExecutionRecordTests.swift    # 历史记录测试
```

## 功能特性

- **命令分组**：支持将命令归类到分组，菜单显示为子菜单
- **快捷键绑定**：为命令设置单键快捷键
- **命令搜索**：在设置窗口实时搜索过滤命令
- **执行历史**：记录最近 100 条执行记录（Cmd+H 打开）
- **错误处理**：保存失败时自动回滚，UI 显示错误提示
- **原子写入**：配置文件先写临时文件再替换，防止数据损坏
- **超时机制**：命令执行 30 秒超时自动终止

## 配置文件格式

配置路径：`~/.config/menu-bar-executor/commands.json`

```json
{
  "commands": [
    {
      "id": "UUID",
      "name": "命令名称",
      "command": "echo 'hello'",
      "workingDirectory": "~",
      "icon": "terminal.fill",
      "notification": true,
      "group": "分组名称",
      "shortcut": "r"
    }
  ]
}
```

历史路径：`~/.config/menu-bar-executor/history.json`

## 开发规范

- 使用 `@MainActor` + `static let shared` 实现单例
- 使用 `NSStatusItem` + `NSMenu` 实现菜单栏
- 使用 `@ObservedObject` 引用单例（非 `@StateObject`）
- Command 使用 UUID 作为唯一标识符（非 name）
- 配置保存使用原子写入 + 回滚机制
- App 设置 `LSUIElement = true` 隐藏 Dock 图标

## 构建

```bash
# 生成项目
xcodegen generate

# 构建
xcodebuild -project menu-bar-executor.xcodeproj -scheme MenuBarExecutor -configuration Debug -derivedDataPath ./build build

# 运行
pkill -f MenuBarExecutor; open ./build/Build/Products/Debug/MenuBarExecutor.app

# 测试
xcodebuild test -project menu-bar-executor.xcodeproj -scheme MenuBarExecutorTests -destination 'platform=macOS'

# 检查配置
cat ~/.config/menu-bar-executor/commands.json
```

## 其他

每次修改后重新构建并重启应用：
```bash
pkill -f MenuBarExecutor && xcodebuild -project menu-bar-executor.xcodeproj -scheme MenuBarExecutor build && open ./build/Build/Products/Debug/MenuBarExecutor.app
```
