# MenuBarExecutor

macOS 菜单栏命令执行器，通过命令面板快速执行自定义 Shell 命令。

## 功能特性

- **命令面板**：全局快捷键切换，实时搜索与高亮，键盘导航（↑↓ 选择、Enter 执行、Esc 关闭），⌘+1~9 快捷执行
- **命令管理**：图形界面添加/编辑/删除命令，拖拽排序，导入导出 JSON 配置
- **输入法切换**：打开面板时可自动切换到默认输入法（可选）
- **执行历史**：记录最近 100 条执行记录，执行完成后显示系统通知
- **配置文件监听**：外部修改配置文件时自动重新加载
- **版本更新**：启动时自动检查更新，支持跳过版本，GitHub API 限流时提供直接访问选项

## 系统要求

- macOS 12.0+
- Xcode 15.0+（仅开发时需要）

## 安装

### 从 Release 下载

1. 从 [Releases](../../releases) 页面下载最新版本
2. 解压并将 `MenuBarExecutor.app` 拖入 `Applications` 文件夹
3. 首次运行可能需要在「系统设置 > 隐私与安全性」中允许运行

### 从源码构建

```bash
git clone https://github.com/11ze/menu-bar-executor.git
cd menu-bar-executor
brew install xcodegen          # 如未安装
xcodegen generate
xcodebuild -project menu-bar-executor.xcodeproj -scheme MenuBarExecutor -configuration Release -derivedDataPath ./build build
open ./build/Build/Products/Release/MenuBarExecutor.app
```

## 使用方法

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| 全局快捷键 | 切换命令面板显示/隐藏（可在设置中配置） |
| `⌘+1~9` | 快速执行当前可见的命令 |
| `↑` `↓` | 在命令面板中选择命令 |
| `Enter` | 执行选中的命令 |
| `Esc` | 清空搜索 / 关闭面板 |
| `Cmd+,` | 打开设置窗口 |
| `Cmd+H` | 打开执行历史 |
| `Cmd+R` | 重载设置文件 |

### 菜单栏交互

- **左键点击**：切换命令面板显示/隐藏
- **右键点击**：显示设置菜单（重载设置、设置、历史、检查更新、退出）

### 添加命令

1. 右键点击菜单栏图标，选择「设置...」（或按 `Cmd+,`）
2. 点击「+」按钮添加新命令
3. 填写命令信息：
   - **名称**：显示在命令面板中的名称
   - **命令**：要执行的 Shell 命令
   - **工作目录**：命令执行的目录（默认 `~`）
   - **显示通知**：执行完成后是否显示通知

### 导入导出配置

在设置窗口中：
- 点击「导出」按钮，将当前配置保存为 JSON 文件
- 点击「导入」按钮，从 JSON 文件加载配置（会覆盖当前配置）

## 配置文件

配置路径：`~/.config/menu-bar-executor/settings.json`

```json
{
  "commands": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Ping Google",
      "command": "ping -c 3 google.com",
      "workingDirectory": "~",
      "notification": true
    }
  ],
  "palettePosition": { "x": 100, "y": 200 },
  "paletteSize": { "width": 500, "height": 480 },
  "defaultInputSourceID": "com.apple.keylayout.ABC",
  "launchAtLogin": false
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | String | 是 | UUID 格式的唯一标识符 |
| `name` | String | 是 | 命令名称 |
| `command` | String | 是 | 要执行的 Shell 命令 |
| `workingDirectory` | String | 否 | 工作目录，默认 `~` |
| `notification` | Bool | 否 | 是否显示通知，默认 `true` |

## 许可证

MIT License
