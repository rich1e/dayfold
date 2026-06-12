# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Commit

- **commit message 必须使用中文**，格式遵循 Conventional Commits：`类型: 描述`
- 常用类型：`feat`、`fix`、`refactor`、`docs`、`chore`、`test`
- 示例：`feat: 添加日历模式月历网格`、`fix: 修复抽屉吸附高度计算`

## 构建与验证

修改代码后在声明完成前必须运行构建：

```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -5
```

- 多文件 bug 修复结束后，按文件汇总根本原因和修复内容
- SourceKit 在 CLI 环境下会对跨文件类型报误，以 `xcodebuild` 的 BUILD SUCCEEDED / FAILED 为准

## 架构概览

MVVM + SwiftUI，数据层为 Core Data（`NSPersistentCloudKitContainer`）。

```
dayfold/dayfold/
├── dayfoldApp.swift          # App 入口，SecurityManager 锁屏集成
├── dayfold.xcdatamodeld/     # Core Data schema（Entry / MediaAsset / Location / Tag）
├── Models/                   # NSManagedObject 扩展：计算属性、工厂方法
├── Services/
│   ├── CoreDataStack.swift   # 单例，lazy persistentContainer，无 iCloud 账号时自动降级本地存储
│   ├── MediaService.swift    # 异步读写磁盘图片，路径验证防路径穿越
│   ├── LocationService.swift # @MainActor CLLocationManager 封装
│   ├── WeatherService.swift  # WeatherKit 封装
│   └── SecurityManager.swift # LocalAuthentication Face ID/Touch ID
├── ViewModels/
│   ├── EntryListViewModel.swift   # 搜索 / 标签收藏筛选 / 删除
│   ├── EntryEditorViewModel.swift # @MainActor；auto-save 2 秒；编辑已有日记时异步加载已存图片
│   ├── TimelineViewModel.swift    # 日期查询、月历圆点 Map、月份导航
│   └── TagManagerViewModel.swift  # 标签 CRUD
└── Views/
    ├── MainTabView.swift          # 三 Tab：时间轴 / 全部 / 标签
    ├── Entry/                     # EntryListView / EntryDetailView / EntryEditorView / Components
    ├── Timeline/                  # TimelineView / CalendarView / MonthGridView / EntryBottomSheet / PhotoWallView
    ├── Tags/                      # TagsView / TagEditorView
    └── Common/                    # EntryHeader / MediaGrid / WarmCardView
```

## 关键设计约定

**Core Data 刷新**
- `@FetchRequest` 只感知对象集合增删；行内属性/关系变化需在对应 View 将 `NSManagedObject` 声明为 `@ObservedObject var`，否则 UI 不刷新。
- 目前 `EntryCard`、`EntryHeader`、`TagRow`、`EntryDetailView` 均已改为 `@ObservedObject`。

**图片管理**
- 图片文件存储在 App Documents/Media 目录，数据库只存文件名（`MediaAsset.filename`）。
- `EntryEditorViewModel` 用 `imagesChanged` 脏标记控制：仅在用户增删图片时保存时全量重建 MediaAsset，未改动则跳过，避免重复写入。
- `loadExistingImages` 异步加载，完成后若 `imagesChanged` 已为 true（用户已先操作）则不覆盖。

**`.task(id:)` 模式**
- 列表卡片缩略图用 `.task(id: thumbnailSourceID)` 绑定 filename 拼接串，asset 变化时自动重载，而非一次性 `.task`。

**Sheet 时序**
- 用 `.sheet(item:)` 而非 `.sheet(isPresented:)` + 独立 `@State` 日期，避免 SwiftUI 同帧捕获旧值导致 `prefillDate` 失效。

**暖色主题**
- 颜色：`Color.warmPaper / warmCream / warmLight / warmBrown / warmAccent / warmGray / warmDark`（`Extensions/Color+Warm.swift`）
- 字体：`Font.warmTitle / warmHeadline / warmBody / warmCaption / warmFootnote`（`Extensions/Font+Warm.swift`）
- 卡片样式：`.warmCard()` modifier（`Extensions/View+Extensions.swift`）

## 已知可忽略的 Xcode 日志

详见 `docs/XCODE_KNOWN_LOGS.md`，包括：启动遥测、iCloud 账号缓存提示、键盘辅助栏约束冲突、辅助功能类未找到。CloudKit `CKAccountStatusNoAccount` (134400) 已在代码层面降级处理。
