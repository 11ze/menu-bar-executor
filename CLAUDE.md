# MenuBarExecutor

## 项目概述

macOS 菜单栏命令执行器，通过命令面板快速执行自定义 Shell 命令。支持全局快捷键呼出、实时搜索、键盘导航、命令管理、导入导出和执行历史功能。

## 技术栈

- Swift 5.9+, SwiftUI
- XcodeGen 项目管理
- UserNotifications 通知
- Process 执行 shell 命令
- XCTest 单元测试

## 项目结构

```
Sources/App/
├── MenuBarExecutorApp.swift           # SwiftUI App 入口
├── AppDelegate.swift                  # App 代理，菜单栏管理
├── Command.swift                      # 命令模型（UUID 主键）
├── CommandExecutor.swift              # Shell 命令执行器（30 秒超时）
├── CommandsManager.swift              # 命令管理器（CRUD + 回滚）
├── ConfigLoader.swift                 # 配置文件加载器（原子写入 + 导入导出）
├── NotificationManager.swift          # 通知管理器
├── ExecutionHistory.swift             # 执行历史管理（最近 100 条）
├── HistoryWindowController.swift      # 历史窗口控制器
├── SettingsWindowController.swift     # 设置窗口控制器
├── CommandPaletteWindowController.swift # 命令面板窗口控制器
├── AppSettings.swift                  # 全局设置（面板位置/尺寸/快捷键/输入法）
├── InputSourceHelper.swift            # 输入法切换工具
├── AppError.swift                     # 错误类型定义
├── AppPaths.swift                     # 统一路径管理
├── StringExtensions.swift             # 字符串扩展工具
├── HighlightedText.swift              # 搜索高亮组件
└── Views/
    ├── CommandsListView.swift         # 命令列表视图（搜索 + 导入导出 + 拖拽排序）
    ├── CommandEditorView.swift        # 命令编辑器
    ├── CommandPaletteView.swift       # 命令面板（全局快捷键 + 搜索 + 键盘导航）
    └── HistoryView.swift              # 执行历史视图

Tests/
├── CommandTests.swift                 # Command 模型测试
└── ExecutionRecordTests.swift         # 历史记录测试
```

## 功能特性

### 命令面板

- **全局快捷键**：可在设置中配置快捷键，随时呼出命令面板
- **实时搜索**：输入关键词快速过滤命令，搜索文本高亮显示
- **键盘导航**：↑↓ 选择命令、Enter 执行、Esc 清空搜索/关闭面板
- **快捷执行**：⌘+1~9 快速执行当前可见区域的命令
- **面板记忆**：自动保存面板位置和尺寸
- **输入法切换**：打开面板时可自动切换到默认输入法（可选）

### 命令管理

- **图形界面**：通过设置窗口管理命令（Cmd+, 打开）
- **拖拽排序**：拖动命令列表项调整顺序
- **导入导出**：导出配置为 JSON 文件，导入已有配置

### 执行与历史

- **执行历史**：记录最近 100 条执行记录（Cmd+H 打开）
- **执行通知**：命令执行完成后显示系统通知
- **错误处理**：保存失败时自动回滚，UI 显示错误提示
- **原子写入**：配置文件先写临时文件再替换，防止数据损坏
- **超时机制**：命令执行 30 秒超时自动终止

### 菜单栏交互

- **左键点击**：直接呼出命令面板
- **右键点击**：显示设置菜单（重载配置、设置、历史、退出）

## 配置文件格式

配置路径：`~/.config/menu-bar-executor/commands.json`

```json
{
  "commands": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "命令名称",
      "command": "echo 'hello'",
      "workingDirectory": "~",
      "notification": true
    }
  ]
}
```

历史路径：`~/.config/menu-bar-executor/history.json`

## 开发规范

- 使用 `@MainActor` + `static let shared` 实现单例
- 使用 `NSStatusItem` + `NSMenu` 实现菜单栏（仅保留设置菜单）
- 使用 `@ObservedObject` 引用单例（非 `@StateObject`）
- Command 使用 UUID 作为唯一标识符（非 name）
- 配置保存使用原子写入 + 回滚机制
- App 设置 `LSUIElement = true` 隐藏 Dock 图标
- 命令面板使用 `NSPanel` + `NSVisualEffectView` 实现毛玻璃效果
- 面板键盘事件通过 `NSEvent.addLocalMonitorForEvents` 监听

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

# currentDate
Today's date is 2026-03-21.
