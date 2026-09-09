# 项目文档优化计划

状态：已批准（2026-09-09）

## 背景

README 上轮修完漂移（已暂存）。本轮两件事：删掉"扫一眼就知道"的配置类罗列；目录治理。经核对，其余文档与代码仅 1 处漂移（architecture.md 的 `docs/` 注释），不重写。

## 一、README.md 精简（167 行 → 约 85 行，在工作区改，不动暂存区）

删（app 里展开即见 / 表单自解释）：
- 「配置文件」整节：示例 JSON、命令字段表、全局设置表、自动维护键、导入导出说明
- 「菜单栏交互」ASCII 图（右键菜单项自带标注）
- 「快捷键」表（面板底部提示行已含同样信息，ASCII 图里就有）
- 「添加命令」三步说明

留/换：
- 配置信息缩为一段：路径 `~/.config/menu-bar-executor/settings.json`、外部修改热重载、导入导出在设置窗口
- 功能一览表加「直接执行」一行（承接字段表里唯一不可见的知识：跳过 zshrc 加载，10ms 级启动，代价是 alias/函数/环境变量不可用）
- 「使用方法」缩为几句：全局快捷键默认未设置、设置中录制、左键点图标呼出、命令在设置窗口管理

## 二、docs/architecture.md

- 删「配置文件」一节（与数据流图完全重复，含"字段见 README"尾巴）
- 修漂移：`docs/ # 架构、规范、plans` → `# 架构、规范`
- 项目结构补 `CONTEXT.md  # 领域词汇表`

## 三、目录治理

- `CLAUDE.md`「深入了解」加 CONTEXT.md 一行（AGENTS.md 是软链，自动生效）
- `.gitignore` 加 `plans/`、`.zcode/`
- 删两个已实施的旧计划文件（palette-execution-speed、prompt-audit-claude-md-stateless-ocean）
- 本计划文件随后续清理一并删除或保留，由下次治理决定

## 不做

- conventions.md、RELEASE_NOTES.md 不动；README 的 ASCII 面板图保留（用户已确认）

## 验证

1. 通读改后 README / architecture.md 检查结构连贯、无断链（如残留「见命令字段」类引用）
2. grep "架构、规范、plans"、grep 字段表残留应为零
3. `git status`：plans/、.zcode/ 不再显示未跟踪；README 仍为改动状态
4. 无构建影响，不跑 xcodebuild；完成后执行 check skill
