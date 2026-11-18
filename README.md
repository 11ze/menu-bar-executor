# MenuBarExecutor

把常用 Shell 命令放进 macOS 菜单栏。按快捷键打开面板，输入名称，回车执行。

[下载](https://github.com/11ze/menu-bar-executor/releases/latest) · [交互原型](https://11ze.github.io/menu-bar-executor/)

- 按名称搜索命令，支持键盘导航与 `⌘1` 至 `⌘9` 执行。
- 打开面板时自动执行指定命令，行内查看与复制结果。
- 命令分组、工作目录、执行历史与 JSON 配置导入导出。
- 原生深浅色界面，可调整并保存面板尺寸。

macOS 12.0+ · SwiftUI + AppKit

## 安装

1. 从 [Releases](https://github.com/11ze/menu-bar-executor/releases/latest) 下载并解压，将 `MenuBarExecutor.app` 拖入应用程序文件夹。包内含 Apple Silicon 与 Intel 两个架构。
2. 打开应用。若被系统拦截，在系统设置的“隐私与安全性”中允许打开。

## 从源码构建

需要 Xcode 15.0+ 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
git clone https://github.com/11ze/menu-bar-executor.git
cd menu-bar-executor
brew install xcodegen
xcodegen generate
xcodebuild -project menu-bar-executor.xcodeproj \
  -scheme MenuBarExecutor \
  -configuration Release \
  -derivedDataPath /tmp/menu-bar-executor-build build
open /tmp/menu-bar-executor-build/Build/Products/Release/MenuBarExecutor.app
```

派生数据放在 `/tmp`，避免 iCloud 同步目录的扩展属性导致签名失败。修改 `project.yml` 后需重新运行 `xcodegen generate`。

运行测试：

```bash
xcodebuild test -project menu-bar-executor.xcodeproj \
  -scheme MenuBarExecutorTests \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/menu-bar-executor-build
```

开发约定见 [开发规范](docs/conventions.md) 与 [领域词汇表](CONTEXT.md)。最新版交互原型使用 Ryugi HTML，发布方式见 [设计说明](docs/interface.md#在线预览与发布)。

## 发布

发版由 `.github/workflows/release.yml` 完成，本机不负责上传。

1. 改 `Resources/Info.plist` 的 `CFBundleShortVersionString`，提交并推送。
2. 打 tag 推送：`git tag -a v1.8.0 -m "version 1.8.0" && git push origin v1.8.0`。
3. Actions 的 Release 工作流先校验 tag 与 `Info.plist` 版本一致，再构建通用包并发布到 [Releases](https://github.com/11ze/menu-bar-executor/releases)。构建失败或版本不一致不会产生 release。

补发已有 tag（比如构建失败后重跑）：`gh workflow run release.yml -f tag=v1.8.0`。tag 里带 `-` 的（如 `v1.8.0-beta.1`）标为预发布。

本地 `./release.sh <version>` 仍可打包自测，只在 `Release/` 生成 zip 和发布说明，不上传。

## 许可证

[MIT](LICENSE)
