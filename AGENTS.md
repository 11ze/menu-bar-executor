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

发版：改 `Resources/Info.plist` 版本并提交后，打 `v*` tag 推到 origin，由 [.github/workflows/release.yml](.github/workflows/release.yml) 校验版本、构建通用包（arm64 + x86_64）并发布 Release。`release.sh` 只做本地自测打包，不上传。发布说明由 [scripts/release-notes.sh](scripts/release-notes.sh) 生成，本地和 CI 共用。

## 界面修改

软件界面与 [Ryugi 交互原型](.ryugi/artifacts/html/menu-bar-executor/index.html) 及 [设计说明与验收步骤](docs/interface.md) 保持一致。Ryugi HTML 是唯一原型源，GitHub Pages 展示 main 分支发布的最新版交互原型；评审画板不作为正式稿。修改界面时先核对设计稿并双向同步：常规偏差按稿修复原生实现；若为了还原某处视觉细节需要引入脆弱的 AppKit 桥接或魔改系统控件，在界面美观的前提下允许优先采用稳定原生形态，并同步更新设计稿与说明，保持两者一致。硬检查项：所有可点控件留白必须纳入点击命中区；所有桥接输入框必须做中文 `hasMarkedText()` 保护。

## 深入了解

- [开发规范](docs/conventions.md) —— 配置写入、文件监听、命令镜像、面板、执行
- [领域词汇表](CONTEXT.md) —— Command、分组、面板、执行模式、执行结果等术语定义
