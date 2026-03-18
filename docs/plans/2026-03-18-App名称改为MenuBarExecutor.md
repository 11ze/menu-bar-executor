# App 名称改为 MenuBarExecutor

## Context

当前构建的 App 文件名为 `menu-bar-executor.app`，不符合 macOS 惯例（应使用驼峰命名如 Slack、Raycast）。改为 `MenuBarExecutor.app` 更专业。

## 修改文件

- [project.yml](project.yml)

## 改动

```yaml
# project.yml
targets:
-  menu-bar-executor:           # 删除，改为下面
+  MenuBarExecutor:
    type: application
    ...
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.cai.menu-bar-executor  # 不变
+       PRODUCT_NAME: MenuBarExecutor  # 新增，显式指定 App 显示名称
```

## 验证

```bash
xcodegen generate
xcodebuild -project menu-bar-executor.xcodeproj -scheme MenuBarExecutor -configuration Debug build
ls -la build/Build/Products/Debug/
# 确认生成的是 MenuBarExecutor.app
```
