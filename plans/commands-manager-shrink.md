# 候选 B · CommandsManager 收缩成命令视图适配层

来源：架构审查 2026-08-21（Worth exploring #1）。前置：候选 A 已落地（AppSettingsManager 可测 seam），本候选在其安全网上进行。目标：两条同步链变一条直连、死事务删除、纯函数可测，`shared` 行为零变。

## 决策记录（两轮拷问已定）

| 决策 | 结论 |
|---|---|
| 收缩形状 | 保类型：镜像改 `$settings.map(\.commands).removeDuplicates()` 直连（删通知绕路），CRUD 直通（删 4 段死回滚），lastError 收窄到 import/export |
| settingsDidReload 通知 | 机制连根删：3 个发送点（reloadSilent:290 / reload:412 / importSettings:433）+ Notification.Name 定义 + :432 过时注释（唯一订阅者被直连替代） |
| 纯函数 | filteredCommands / sortedGroupNames 提为 static；sortedGroupNames 参数化 groupOrder（不再偷读 AppSettingsManager.shared）；实例薄壳删，调用点直呼 static |
| 测试投入 | 纯函数钉子：分组排序语义（groupOrder 优先 / 首现序兜底 / nil 殿后）+ 过滤（空搜索 / 大小写不敏感）；CommandsManager 本身不开 seam（去镜像后薄如纸，不过度设计） |
| 冗余声明 | CommandPaletteView:212 body 里从未使用的 @ObservedObject manager 删除，刷新由 coordinator.paletteItems 承担，冒烟验证 |

## 实施步骤（TDD 红绿）

1. 新建 `Tests/CommandsManagerTests.swift`：static sortedGroupNames / filteredCommands 测试 → 红（方法不存在）
2. 两个方法 static 化（sortedGroupNames 加 groupOrder: [String]? 参数）→ 绿
3. 调用点直呼 static：CommandsListView:20-21、PaletteCoordinator:94/116 → 构建
4. 镜像直连：init 订阅 `$settings.map(\.commands).removeDuplicates()`；删 loadCommands() 与 settingsDidReload 订阅 → 构建
5. CRUD 直通：add/update/delete/reorder 删死回滚直调 saveCommands（镜像自动回流）→ 构建
6. `AppSettingsManager.saveCommands` 去 throws；删 3 个通知发送点 + Notification.Name 定义 + :432 注释；CommandsManager.importSettings 里手动同步 commands 一句删（直连自动）→ 构建
7. CommandPaletteView:212 冗余 @ObservedObject 删 → 构建
8. 全量测试 + 冒烟：面板搜索/执行、外部改配置后重开面板、设置窗口 CRUD、导入导出、菜单栏手动重载
9. 文档同步：architecture.md 数据流图（NotificationCenter 一节改 Combine 直连）+ conventions.md（若提及通知）

## 实现裁量（未另行确认的细节）

- `$settings` 的 sink 不加 `receive(on:)`（@Published 赋值发生在 MainActor，sink 同步直通，无延迟）
- lastError / clearError 保留（import/export 真错误仍在用，CommandsListView alert 绑定不动）
- 测试文件名 CommandsManagerTests.swift，纯 static 函数测试无需 @MainActor

## 范围外

- CommandPaletteView 拆分（候选 C）
- save 失败用户可见化（A 时已定范围外）
- AppPaths.ensureDirectoryExists 写死路径（A 审查 advisory，随下次触碰处理）

## 验证

```bash
xcodebuild test -project menu-bar-executor.xcodeproj \
  -scheme MenuBarExecutorTests -destination 'platform=macOS'
# 构建 + 重启冒烟：pkill -f MenuBarExecutor → build 到 /tmp → open
```
