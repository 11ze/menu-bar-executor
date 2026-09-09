# MenuBarExecutor

macOS 菜单栏命令执行器，让你快速执行自定义 Shell 命令。

```
  全局快捷键 → 弹出面板 → 搜索/选择 → 执行 → 搞定
```

## 它能做什么？

```
  你的菜单栏多了一个小图标:
  ┌─────────────────────────────────────────────┐
  │  ████ ▸  ← 点击或按快捷键，弹出命令面板         │
  └─────────────────────────────────────────────┘
                     │
                     ▼
  ┌─────────────────────────────────────────────┐
  │  🔍 搜索命令...                              │
  ├─────────────────────────────────────────────┤
  │  📁 部署相关                                 │
  │  ⚡ 1  deploy:prod     部署到生产环境          │
  │  ⚡ 2  deploy:staging  部署到预发布           │
  │  📁 Docker                                  │
  │  ⚡ 3  docker:up        启动容器              │
  │  ⚡ 4  docker:down      停止容器              │
  ├─────────────────────────────────────────────┤
  │  ↑↓ 选择  Enter 执行  ⌘1-9 快捷执行  Esc 关闭  │
  └─────────────────────────────────────────────┘
```

## 功能一览

| 功能 | 说明 |
|------|------|
| 命令面板 | 全局快捷键呼出、实时搜索高亮、键盘导航、`⌘+1~9` 快捷执行 |
| 命令管理 | 图形界面增删改、拖拽排序、分组管理 |
| 自动执行 | 标记命令在面板打开时自动运行，结果内联显示 |
| 直接执行 | 命令级开关：`zsh -c` 跳过 shell 配置加载，10ms 级启动；代价是 zshrc 里的函数、alias、环境变量不可用 |
| 导入/导出 | JSON 格式配置备份与恢复 |
| 执行历史 | 最近 100 条记录，含执行时间、结果、成功/失败状态 |
| 配置热重载 | 外部修改 `settings.json` 后自动重新加载 |
| 输入法切换 | 打开面板时自动切到指定输入法（可选） |
| 开机自启 | macOS 13+ 原生支持 |
| 版本更新 | 启动时检查 GitHub Release，支持跳过版本 |

## 系统要求

- macOS 12.0+

## 安装

### 从 Release 下载

1. 前往 [Releases](../../releases) 页面下载最新版
2. 解压，将 `MenuBarExecutor.app` 拖入「应用程序」
3. 首次运行需在 **系统设置 > 隐私与安全性** 中允许

### 从源码构建

需要 Xcode 15.0+：

```bash
git clone https://github.com/11ze/menu-bar-executor.git
cd menu-bar-executor
brew install xcodegen          # 首次需要
xcodegen generate
xcodebuild -project menu-bar-executor.xcodeproj \
  -scheme MenuBarExecutor \
  -configuration Release \
  -derivedDataPath /tmp/menu-bar-executor-build build
open /tmp/menu-bar-executor-build/Build/Products/Release/MenuBarExecutor.app
```

## 使用方法

全局快捷键默认未设置，首次使用请在 **设置** 中录制；左键点击菜单栏图标同样可以呼出/关闭面板。命令的增删改、分组与排序都在设置窗口完成（面板打开时按 `⌘+,`）。

## 配置文件

路径：`~/.config/menu-bar-executor/settings.json`。可直接手改，保存后自动热重载；设置窗口中也提供 JSON 导入/导出。

## 许可证

MIT License
