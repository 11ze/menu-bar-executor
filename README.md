# MenuBarExecutor

macOS 菜单栏命令执行器，让你快速执行自定义 Shell 命令。

## 功能特性

- **自定义命令**：添加任意 Shell 命令，一键执行
- **命令分组**：将命令归类到分组，菜单显示为子菜单
- **快捷键绑定**：为命令设置单键快捷键
- **命令搜索**：在设置窗口实时搜索过滤命令
- **执行历史**：记录最近 100 条执行记录（Cmd+H 打开）
- **执行通知**：命令执行完成后显示系统通知
- **图形界面**：通过设置窗口管理命令（Cmd+, 打开）

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
| `Cmd+,` | 打开设置窗口 |
| `Cmd+H` | 打开执行历史 |
| `Cmd+R` | 重载配置文件 |

### 添加命令

1. 点击菜单栏图标，选择「设置...」
2. 点击「+」按钮添加新命令
3. 填写命令信息：
   - **名称**：显示在菜单中的名称
   - **命令**：要执行的 Shell 命令
   - **工作目录**：命令执行的目录（默认 `~`）
   - **图标**：SF Symbols 图标名称
   - **分组**：可选，用于组织命令
   - **快捷键**：可选，单键快捷键
   - **显示通知**：执行完成后是否显示通知

## 配置文件

配置路径：`~/.config/menu-bar-executor/commands.json`

```json
{
  "commands": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Ping Google",
      "command": "ping -c 3 google.com",
      "workingDirectory": "~",
      "icon": "antenna.radiowaves.left.and.right",
      "notification": true,
      "group": "Network",
      "shortcut": "p"
    }
  ]
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | String | 是 | UUID 格式的唯一标识符 |
| `name` | String | 是 | 命令名称 |
| `command` | String | 是 | 要执行的 Shell 命令 |
| `workingDirectory` | String | 否 | 工作目录，默认 `~` |
| `icon` | String | 否 | SF Symbols 图标名称 |
| `notification` | Bool | 否 | 是否显示通知，默认 `true` |
| `group` | String | 否 | 分组名称 |
| `shortcut` | String | 否 | 单键快捷键 |

## 开发

### 项目结构

```
Sources/App/
├── MenuBarExecutorApp.swift      # SwiftUI App 入口
├── AppDelegate.swift             # App 代理，菜单栏管理
├── Command.swift                 # 命令模型
├── CommandExecutor.swift         # Shell 命令执行器
├── CommandsManager.swift         # 命令设置器
├── ConfigLoader.swift            # 配置文件加载器
├── NotificationManager.swift     # 通知管理器
├── ExecutionHistory.swift        # 执行历史管理
└── Views/                        # SwiftUI 视图
    ├── CommandsListView.swift    # 命令列表
    ├── CommandEditorView.swift   # 命令编辑器
    └── HistoryView.swift         # 历史视图

Tests/                            # 单元测试
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
