# MenuBarExecutor

## 项目概述

macOS 菜单栏命令执行器，通过命令面板快速执行自定义 Shell 命令。支持全局快捷键切换、实时搜索、键盘导航、命令管理、导入导出、配置文件自动监听和执行历史功能。

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
├── NotificationManager.swift          # 通知管理器
├── ExecutionHistory.swift             # 执行历史管理（最近 100 条）
├── HistoryWindowController.swift      # 历史窗口控制器
├── SettingsWindowController.swift     # 设置窗口控制器
├── CommandPaletteWindowController.swift # 命令面板窗口控制器
├── AppSettings.swift                  # 统一配置管理（命令 + 窗口设置 + 导入导出）
├── InputSourceHelper.swift            # 输入法切换工具
├── LaunchAtLoginManager.swift         # 开机自启动管理（macOS 13+）
├── UpdateManager.swift                # 版本更新检查管理器
├── UpdateInfo.swift                   # 版本更新信息模型
├── AppError.swift                     # 错误类型定义
├── AppPaths.swift                     # 统一路径管理
├── StringExtensions.swift             # 字符串扩展工具
├── HighlightedText.swift              # 搜索高亮组件
├── CommandPaletteView.swift           # 命令面板（全局快捷键 + 搜索 + 键盘导航）
└── Views/
    ├── CommandsListView.swift         # 命令列表视图（搜索 + 导入导出 + 拖拽排序）
    ├── CommandEditorView.swift        # 命令编辑器
    └── HistoryView.swift              # 执行历史视图

Scripts/
├── update_build_number.sh             # 自动更新构建号脚本
├── create_icons.py                    # 创建图标脚本
└── generate_appicon.py                # 生成 App 图标脚本

Tests/
├── AppErrorTests.swift                # 错误类型测试
├── AppSettingsTests.swift             # 配置管理测试
├── CommandTests.swift                 # Command 和 AppSettings 测试
├── ExecutionRecordTests.swift         # 历史记录测试
├── HighlightedTextRangeTests.swift    # 高亮文本范围测试
├── StringExtensionsTests.swift        # 字符串扩展测试
└── UpdateInfoTests.swift              # 版本信息测试

release.sh                             # 自动化发布脚本（版本号更新 + git tag + release notes）
```

## 配置文件

- 设置：`~/.config/menu-bar-executor/settings.json`（详细格式见 README.md）
- 历史：`~/.config/menu-bar-executor/history.json`

## 开发规范

- 使用 `@MainActor` + `static let shared` 实现单例
- 使用 `NSStatusItem` + `NSMenu` 实现菜单栏（仅保留设置菜单）
- 使用 `@ObservedObject` 引用单例（非 `@StateObject`）
- Command 使用 UUID 作为唯一标识符（非 name）
- 配置保存使用原子写入 + 回滚机制
- App 设置 `LSUIElement = true` 隐藏 Dock 图标
- 命令面板使用 `NSPanel` + `NSVisualEffectView` 实现毛玻璃效果
- 面板键盘事件通过 `NSEvent.addLocalMonitorForEvents` 监听
- 配置文件监听使用 `DispatchSource.makeFileSystemObjectSource` 实现

## 构建

```bash
# 生成项目
xcodegen generate

# Debug 构建
xcodebuild -project menu-bar-executor.xcodeproj -scheme MenuBarExecutor -configuration Debug -derivedDataPath ./build build

# 运行测试
xcodebuild test -project menu-bar-executor.xcodeproj -scheme MenuBarExecutorTests -destination 'platform=macOS'

# 重新构建并重启（日常开发用）
pkill -f MenuBarExecutor && xcodebuild -project menu-bar-executor.xcodeproj -scheme MenuBarExecutor build && open ./build/Build/Products/Debug/MenuBarExecutor.app
```
