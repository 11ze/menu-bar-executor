# menu-bar-exector

## 项目概述

macOS 菜单栏命令执行器，在菜单栏显示自定义命令，点击后执行并显示通知。

## 技术栈

- Swift 5.9+, SwiftUI
- XcodeGen 项目管理
- UserNotifications 通知
- Process 执行 shell 命令

## 开发规范

- 使用 `@MainActor` + `static let shared` 实现单例
- 使用 `NSStatusItem` + SwiftUI Menu 实现菜单栏
- 配置文件路径：`~/.config/menu-bar-exector/commands.json`
- App 设置 `LSUIElement = true` 隐藏 Dock 图标
- 使用 Combine 监听命令列表变化自动刷新菜单

## 构建

- 运行 `xcodegen generate` 生成项目
- 需要完整 Xcode（CommandLineTools 不支持 `xcodebuild`）
