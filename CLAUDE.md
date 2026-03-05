# menu-bar-executor

## 项目概述

macOS 菜单栏命令执行器，在菜单栏显示自定义命令，点击后执行并显示通知。支持图形界面命令管理功能。

## 技术栈

- Swift 5.9+, SwiftUI
- XcodeGen 项目管理
- UserNotifications 通知
- Process 执行 shell 命令

## 项目结构

```
Sources/App/
├── menu_bar_exectorApp.swift    # SwiftUI App 入口
├── AppDelegate.swift            # App 代理
├── Command.swift                # 命令模型
├── CommandExecutor.swift         # Shell 命令执行器
├── NotificationManager.swift     # 通知管理器
├── ConfigLoader.swift            # 配置文件加载器
├── CommandsManager.swift         # 命令管理器（增删改查）
├── StatusBarView.swift           # 菜单栏视图
├── SettingsWindowController.swift # 设置窗口控制器
└── Views/
    ├── CommandsListView.swift    # 命令列表视图
    └── CommandEditorView.swift   # 命令编辑器视图
```

## 开发规范

- 使用 `@MainActor` + `static let shared` 实现单例
- 使用 `NSStatusItem` + SwiftUI Menu 实现菜单栏
- 配置文件路径：`~/.config/menu-bar-executor/commands.json`
- App 设置 `LSUIElement = true` 隐藏 Dock 图标
- 使用 Combine 监听命令列表变化自动刷新菜单
- 从菜单栏「命令设置」入口可打开图形界面管理命令

## 构建

- 运行 `xcodegen generate` 生成项目
- 需要完整 Xcode（CommandLineTools 不支持 `xcodebuild`）
- 构建命令：`xcodebuild -project menu-bar-executor.xcodeproj -scheme menu-bar-executor -configuration Debug -derivedDataPath ./build build`
- 构建产物位于 `./build/Build/Products/Debug/`
- 打开应用：`open ./build/Build/Products/Debug/menu-bar-executor.app`
- 检查配置：`cat ~/.config/menu-bar-executor/commands.json`

## 其他

每次修改后都重新构建项目、关掉已打开的进程并重新打开应用
- 关闭已打开的进程：`pkill -f menu-bar-executor`
