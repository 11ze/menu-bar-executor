# 候选 A · AppSettingsManager 可测 seam

来源：架构审查 2026-08-21（Top recommendation）。目标：解锁 Manager 约 320 行零测试行为，shared 行为零变，为候选 B/C 建安全网。

## 决策记录（两轮拷问已定）

| 决策 | 结论 |
|---|---|
| seam 形状 | internal `init(filePath: URL, enableFileMonitoring: Bool = true)`，shared 走 AppPaths，无协议无新类型 |
| 迁移归宿 | 三件套提为 `AppSettings.migrateIfNeeded(_ settings: inout AppSettings) -> Bool` static 纯函数，单入口，内部顺序不变 |
| bug① skip 残留 | 修：save() catch 复位 skipNextFileChange + 一行 print（不留用户可见错误面） |
| bug② fd 泄漏 | 修：startFileMonitoring 开头先 stopFileMonitoring（幂等） |
| 写帧事务 | updatePaletteFrame 内部收口为 load(notifyError: false) → 改帧 → save；删 CommandPaletteWindowController.hide() 的裸调 load |
| 测试投入 | 纯逻辑钉子 + 两个真监听集成（自身 save 不触发重载、外部写触发重载，各 ~1s） |

## 实施步骤（TDD 红绿）

1. 新建 `Tests/AppSettingsManagerTests.swift`：迁移纯函数测试（假分组迁移、重复 UUID 修复、无迁移不写盘）→ 红
2. 迁移三件套提纯为 `AppSettings.migrateIfNeeded(&:)`，load() 改调用 → 绿
3. Manager 钉子测试：坏 JSON 拒写（isLoaded 守卫，06d720f 同类防线）、临时目录 save/load 往返、原子替换 → 红
4. 加 internal init(filePath:enableFileMonitoring:)，private init 收敛为默认参数调用 → 绿
5. bug① 复现测试：save 失败（目录不可写）后，真实外部写入仍触发重载 → 红
6. 修 save() catch：复位标志 + print → 绿
7. bug② 行为断言：构造迁移场景（旧格式文件 + enableFileMonitoring: true），外部写入仍触发重载 → 红
8. startFileMonitoring 先 stop → 绿
9. 监听集成 ×2：自身 save 不触发 settingsDidReload；外部写触发（0.3s 防抖 + 真等待）
10. updatePaletteFrame 收口 + 对应测试（外部改磁盘后写帧，磁盘其他字段不丢）；删 hide() 裸调（CommandPaletteWindowController.swift:176）
11. 文档同步：docs/architecture.md 配置写入一节 + 行号引用

## 实现裁量（未另行确认的细节）

- 迁移签名用 inout（Swift 惯用），测试文件名 `AppSettingsManagerTests.swift`（与值类型测试分开，名实相符）
- enableFileMonitoring 默认 true（shared 无感），测试显式传
- @MainActor 测试用 `@MainActor func test…` + 临时目录（FileManager.temporaryDirectory 子目录，tearDown 清理）

## 范围外

- CommandsManager 死 throws + 4 段回滚（候选 B）
- CommandPaletteView 拆分（候选 C）
- save 失败用户可见化（行为零变承诺）

## 验证

```bash
xcodebuild test -project menu-bar-executor.xcodeproj \
  -scheme MenuBarExecutorTests -destination 'platform=macOS'
# 构建 + 重启 App 冒烟：pkill -f MenuBarExecutor → build → open
```
