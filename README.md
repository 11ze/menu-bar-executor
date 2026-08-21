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
| 导入/导出 | JSON 格式配置备份与恢复 |
| 执行历史 | 最近 100 条记录，含执行时间、结果、成功/失败状态 |
| 配置热重载 | 外部修改 `settings.json` 后自动重新加载 |
| 输入法切换 | 打开面板时自动切到指定输入法（可选） |
| 开机自启 | macOS 13+ 原生支持 |
| 版本更新 | 启动时检查 GitHub Release，支持跳过版本 |

## 系统要求

- macOS 12.0+
- 开发需要 Xcode 15.0+

## 安装

### 从 Release 下载

1. 前往 [Releases](../../releases) 页面下载最新版
2. 解压，将 `MenuBarExecutor.app` 拖入「应用程序」
3. 首次运行需在 **系统设置 > 隐私与安全性** 中允许

### 从源码构建

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

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| 全局快捷键 | 呼出/关闭命令面板（可在设置中配置） |
| `⌘+1` ~ `⌘+9` | 快捷执行第 N 条可见命令 |
| `↑` `↓` | 上下选择命令 |
| `Enter` | 执行选中命令 |
| `Esc` | 清空搜索，再按关闭面板 |
| `⌘+,` | 打开设置窗口 |
| `⌘+H` | 打开执行历史 |
| `⌘+R` | 重载设置文件 |

### 菜单栏交互

```
  左键点击图标 ──▶ 呼出/关闭命令面板
  右键点击图标 ──▶ 弹出菜单:
                    ├── 设置...       ⌘,
                    ├── 重载设置      ⌘R
                    ├── 执行历史      ⌘H
                    ├── ─────────────
                    ├── 检查更新
                    ├── ─────────────
                    └── 退出          ⌘Q
```

### 添加命令

1. 右键菜单栏图标 → **设置...**（或 `⌘+,`）
2. 点击 **+** 添加新命令
3. 填写信息：

| 字段 | 说明 |
|------|------|
| 名称 | 面板中显示的命令名 |
| 命令 | 要执行的 Shell 命令 |
| 工作目录 | 命令执行的目录（默认 `~`） |
| 显示通知 | 执行完成后弹出系统通知 |
| 自动执行 | 打开面板时自动运行，结果内联显示 |
| 分组 | 归属的分组名称（可选） |

### 导入导出

在设置窗口中点击「导出」/「导入」按钮，JSON 格式备份和恢复配置。

## 配置文件

路径：`~/.config/menu-bar-executor/settings.json`

```json
{
  "commands": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Ping Google",
      "command": "ping -c 3 google.com",
      "workingDirectory": "~",
      "notification": true,
      "autoExecute": false,
      "group": "网络工具"
    }
  ],
  "palettePosition": { "x": 100, "y": 200 },
  "paletteSize": { "width": 500, "height": 480 },
  "defaultInputSourceID": "com.apple.keylayout.ABC",
  "launchAtLogin": false,
  "groupOrder": ["网络工具", "部署"]
}
```

### 命令字段

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `id` | String | 是 | 自动生成 | UUID 格式唯一标识 |
| `name` | String | 是 | - | 命令名称 |
| `command` | String | 是 | - | Shell 命令 |
| `workingDirectory` | String | 否 | `~` | 工作目录 |
| `notification` | Bool | 否 | `true` | 执行后是否显示系统通知 |
| `autoExecute` | Bool | 否 | `false` | 打开面板时自动执行 |
| `group` | String | 否 | `null` | 分组名称 |

### 全局设置

| 字段 | 类型 | 说明 |
|------|------|------|
| `palettePosition` | Object | 面板位置 `{x, y}` |
| `paletteSize` | Object | 面板尺寸 `{width, height}` |
| `defaultInputSourceID` | String | 打开面板时切换到的输入法 ID |
| `launchAtLogin` | Bool | 开机自启 |
| `groupOrder` | [String] | 分组显示顺序 |

## 许可证

MIT License
