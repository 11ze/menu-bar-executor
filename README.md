# MenuBarExecutor

macOS 菜单栏命令执行器，通过命令面板快速执行自定义 Shell 命令。

## 功能特性

- **命令面板**：全局快捷键呼出，实时搜索，键盘导航
- **搜索高亮**：搜索文本在结果中高亮显示
- **快捷执行**：⌘+1~9 快速执行当前可见的命令
- **面板记忆**：自动保存面板位置和尺寸
- **输入法切换**：打开面板时可自动切换到默认输入法（可选）
- **命令管理**：图形界面管理命令（Cmd+, 打开设置）
- **拖拽排序**：拖动命令列表项调整顺序
- **导入导出**：导出配置为 JSON 文件，导入已有配置
- **执行历史**：记录最近 100 条执行记录（Cmd+H 打开）
- **执行通知**：命令执行完成后显示系统通知

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
# 克隆仓库
git clone https://github.com/yourusername/menu-bar-executor.git
cd menu-bar-executor

# 安装 XcodeGen（如未安装）
brew install xcodegen

# 生成并构建项目
xcodegen generate
xcodebuild -project menu-bar-executor.xcodeproj -scheme MenuBarExecutor -configuration Release -derivedDataPath ./build build

# 运行
open ./build/Build/Products/Release/MenuBarExecutor.app
```

## 使用方法

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| 全局快捷键 | 呼出命令面板（可在设置中配置） |
| `⌘+1~9` | 快速执行当前可见的命令 |
| `↑` `↓` | 在命令面板中选择命令 |
| `Enter` | 执行选中的命令 |
| `Esc` | 清空搜索 / 关闭面板 |
| `Cmd+,` | 打开设置窗口 |
| `Cmd+H` | 打开执行历史 |
| `Cmd+R` | 重载配置文件 |

### 菜单栏交互

- **左键点击**：直接呼出命令面板
- **右键点击**：显示设置菜单（重载配置、设置、历史、退出）

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
  "windowPosition": { "x": 100, "y": 200 },
  "windowSize": { "width": 400, "height": 300 },
  "defaultInputSourceID": "com.apple.keylayout.ABC"
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

## 开发

### 项目结构

```
Sources/App/
├── MenuBarExecutorApp.swift           # SwiftUI App 入口
├── AppDelegate.swift                  # App 代理，菜单栏管理
├── Command.swift                      # 命令模型
├── CommandExecutor.swift              # Shell 命令执行器
├── CommandsManager.swift              # 命令管理器
├── NotificationManager.swift          # 通知管理器
├── ExecutionHistory.swift             # 执行历史管理
├── HistoryWindowController.swift      # 历史窗口控制器
├── SettingsWindowController.swift     # 设置窗口控制器
├── CommandPaletteWindowController.swift # 命令面板窗口控制器
├── AppSettings.swift                  # 统一配置管理
├── InputSourceHelper.swift            # 输入法切换工具
├── AppError.swift                     # 错误类型定义
├── AppPaths.swift                     # 统一路径管理
├── StringExtensions.swift             # 字符串扩展工具
├── HighlightedText.swift              # 搜索高亮组件
└── Views/                             # SwiftUI 视图
    ├── CommandsListView.swift         # 命令列表
    ├── CommandEditorView.swift        # 命令编辑器
    ├── CommandPaletteView.swift       # 命令面板
    └── HistoryView.swift              # 历史视图

Tests/                                 # 单元测试
├── CommandTests.swift
└── ExecutionRecordTests.swift
```

### 构建与测试

```bash
# 生成项目
xcodegen generate

# Debug 构建
xcodebuild -project menu-bar-executor.xcodeproj -scheme MenuBarExecutor -configuration Debug -derivedDataPath ./build build

# 运行测试
xcodebuild test -project menu-bar-executor.xcodeproj -scheme MenuBarExecutorTests -destination 'platform=macOS'

# 打包发布版本
./release.sh 1.0.0
```

## 许可证

MIT License
