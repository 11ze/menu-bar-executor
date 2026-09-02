# MenuBarExecutor

macOS 菜单栏命令执行器的领域词汇表：全局快捷键唤出面板，搜索并执行自定义 shell 命令。

## Language

**Command（命令）**:
用户自定义的一条 shell 命令，以 UUID 为主键，可分组、可标记通知与自动执行。
_Avoid_: 脚本、任务

**分组（group）**:
Command 的归属标签，决定面板里的分区显示与排序。
_Avoid_: 目录、文件夹

**命令面板（Palette）**:
全局快捷键唤出的搜索执行面板，Command 的手动执行入口。
_Avoid_: 弹窗、下拉

**⚡ 自动执行（autoExecute）**:
打开面板时自动运行的 Command，结果只内联显示在面板行内。
_Avoid_: 后台命令、定时任务

**直接执行（directExecution）**:
Command 的执行方式标记：开启后用 `zsh -c` 跳过 shell 配置加载（默认 `-i -l` 会加载 ~/.zshrc 与 ~/.zprofile）。换取 10ms 级启动，代价是 zshrc 里的函数、alias 与环境变量不可用。
_Avoid_: 快速模式、裸 shell

**执行历史（ExecutionHistory）**:
用户主动执行留下的最近记录（上限 100 条）。⚡ 自动执行不计入。
_Avoid_: 日志

**执行模式（ExecutionMode）**:
一次执行的触发方式：用户主动（userInitiated）或面板自动（auto）。模式决定这次执行是否计入执行历史、是否发系统通知。
_Avoid_: 执行路径

**执行结果（ExecutionResult）**:
一次命令运行的结局：成功、非零退出（命令跑了但失败）、没跑起来（超时或启动失败）。输出只是结果携带的一部分。
_Avoid_: 输出、返回值
