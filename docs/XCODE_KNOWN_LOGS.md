# Xcode 控制台已知日志（无需处理）

记录运行 Dayfold 时 Xcode 控制台常见、但**不影响功能、无需修改代码**的日志，避免后续重复排查或误提交修复。

> 判断原则：本地 Core Data 读写正常、UI 行为符合预期时，下列日志均为模拟器 / 系统框架噪音或环境性提示，可直接忽略。

---

## 可直接忽略的日志

### 1. App 启动遥测

```
Failed to send CA Event for app launch measurements for ca_event_type: 0
event_name: com.apple.app_launch_measurement.FirstFramePresentationMetric
```

- **性质**：系统启动性能埋点遥测，模拟器环境常见。
- **处理**：忽略，与应用代码无关。

### 2. 账号信息缓存校验

```
Could not validate account info cache. (This is a potential performance issue.)
```

- **性质**：模拟器未登录 iCloud 账号时的提示。
- **处理**：忽略；如需测试 CloudKit 同步，在模拟器「设置」登录 iCloud 即可。

### 3. 辅助功能类未找到

```
AX Safe category class 'SLHighlightDisambiguationPillViewAccessibility' was not found!
```

- **性质**：系统 Accessibility 框架内部日志。
- **处理**：忽略，与应用代码无关。

---

## 已做代码降级的日志

### CloudKit 无 iCloud 账号（已处理）

```
CoreData+CloudKit: Failed to set up CloudKit integration for store ...
Error Domain=NSCocoaErrorDomain Code=134400
"Unable to initialize without an iCloud account (CKAccountStatusNoAccount)."
CoreData+CloudKit: Attempting recovery from error ... 134400
CoreData+CloudKit: Failed to recover from error: NSCocoaErrorDomain:134400
```

- **性质**：模拟器 / 设备未登录 iCloud，`NSPersistentCloudKitContainer` 无法初始化 CloudKit 镜像，并反复 recovery。
- **影响**：本地 Core Data 读写**不受影响**，仅云同步无法建立。
- **代码处理**：`Services/CoreDataStack.swift` 在加载失败且错误码为 `134400` 时，移除 `cloudKitContainerOptions` 并重新加载，退化为纯本地存储，不再反复刷错误日志（提交 `269ddc0`）。
- **完整云同步验证**：需在模拟器 / 真机登录 iCloud 账号后运行。

---

## 维护说明

- 新发现的「确认可忽略」日志，追加到「可直接忽略的日志」一节，注明性质与处理。
- 若某条日志后续被确认为真实 bug，将其移出本文档并提交修复。
