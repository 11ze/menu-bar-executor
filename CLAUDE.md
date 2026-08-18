# MenuBarExecutor

macOS 菜单栏命令执行器 —— 全局快捷键弹出面板，搜索并执行自定义 Shell 命令。

Swift 5.9+ / SwiftUI + AppKit。项目由 XcodeGen 管理：改过 `project.yml` 后先 `xcodegen generate` 再构建。依赖 KeyboardShortcuts（SPM）。

## 构建

```bash
# 构建（默认 Debug 配置）
# 注意：必须构建到 /tmp 而非 ./build——项目位于 iCloud 同步路径下，
# iCloud 注入的扩展属性会导致 codesign 失败（release.sh 同理）。
xcodebuild -project menu-bar-executor.xcodeproj \
  -scheme MenuBarExecutor \
  -derivedDataPath /tmp/menu-bar-executor-build build

# 日常重建重启 = pkill -f MenuBarExecutor → 上面构建 → open /tmp/menu-bar-executor-build/Build/Products/Debug/MenuBarExecutor.app

# 测试（独立 scheme）
xcodebuild test -project menu-bar-executor.xcodeproj \
  -scheme MenuBarExecutorTests \
  -destination 'platform=macOS'
```

## 深入了解

- [架构与数据流](docs/architecture.md) —— 技术栈、模块关系、命令执行流程、项目结构、配置文件
- [开发规范](docs/conventions.md) —— 单例、Command 主键、配置写入、文件监听、面板
