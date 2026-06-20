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

MVVM + SwiftUI，数据层为 Core Data（`NSPersistentCloudKitContainer`），无 iCloud 账号自动降级本地存储。

**导航结构**：抽屉式而非 TabBar。`MainTabView` 是根容器，左侧抽屉占屏宽 85% 由 `SidebarView/DrawerView` 实现，内容区根据 `selectedTab: SidebarTab` 切换；首页（`HomeView`）展示笔记本封面墙，点击封面以 `fullScreenCover` 推入 `NotebookDetailView`。

```
dayfold/dayfold/
├── dayfoldApp.swift              # App 入口，注入 viewContext，集成 SecurityManager 锁屏
├── ContentView.swift             # 旧入口（保留，未使用）
├── Persistence.swift             # PersistenceController（SwiftUI 模板遗留，CoreDataStack 才是实际单例）
├── dayfold.xcdatamodeld/         # Core Data schema（Entry / MediaAsset / Location / Tag）
├── Models/                       # NSManagedObject 扩展：计算属性、工厂方法（create / moveToTrash / restore）
├── Services/
│   ├── CoreDataStack.swift       # 单例，lazy persistentContainer，CloudKit 134400 降级本地；提供 viewContext / save()
│   ├── MediaService.swift        # 异步读写 Documents/Media 目录图片，路径验证防穿越，缩略图生成
│   ├── LocationService.swift     # @MainActor CLLocationManager 封装，反向地理编码 placeName
│   ├── WeatherService.swift      # WeatherKit 封装
│   ├── SecurityManager.swift     # LocalAuthentication Face ID / Touch ID 锁屏
│   └── CardExporter.swift        # 单条日记导出为图片卡片（用于分享）
├── ViewModels/                   # 全部 @MainActor ObservableObject
│   ├── EntryListViewModel.swift  # 搜索 / 标签 / 收藏筛选 / 删除
│   ├── EntryEditorViewModel.swift# auto-save 2s；imagesChanged 脏标记；编辑时异步加载已存图片
│   ├── TimelineViewModel.swift   # 日期查询、月历圆点 Map、月份导航
│   └── TagManagerViewModel.swift # 标签 CRUD
├── Views/
│   ├── MainTabView.swift         # 根容器：抽屉 + 内容区，selectedTab 驱动切换
│   ├── SidebarView.swift         # DrawerView，SidebarTab 枚举
│   ├── HomeView.swift            # 笔记本封面墙 + fullScreenCover 推入 NotebookDetailView
│   ├── NotebookDetailView.swift  # 单笔记本时间轴（按月分组 + 同日合并），左滑删除，底部 + 新建
│   ├── LockScreenView.swift      # 生物识别锁屏 UI
│   ├── Entry/
│   │   ├── EntryListView.swift           # 全部日记列表（搜索 / 筛选）
│   │   ├── EntryDetailView.swift         # 日记详情
│   │   ├── EntryEditorView.swift         # 新建 / 编辑，键盘工具栏，图片选择
│   │   ├── EntryCardPreviewSheet.swift   # 导出卡片预览
│   │   ├── TrashView.swift               # 回收站（soft-delete 恢复 / 永久删除）
│   │   └── Components/                   # EntryCardView / MediaPicker / TagPicker / MarkdownEditor / FormattingToolbar
│   ├── Timeline/                 # TimelineView / TimelineListView / CalendarView / MonthGridView / EntryBottomSheet / PhotoWallView
│   ├── Tags/                     # TagsView / TagEditorView
│   └── Common/                   # EntryHeader / MediaGrid / WarmCardView
└── Extensions/                   # Color+Warm / Font+Warm / Transitions+Warm / View+Extensions（cornerRadius / warmCard / hideKeyboard）
```

**数据流向**

- `dayfoldApp` → `@Environment(\.managedObjectContext)` 注入 `CoreDataStack.shared.viewContext`
- 所有 View 通过 `@Environment` 取 context，避免 init 显式传参导致的实例不一致（fullScreenCover / sheet 内务必再次 `.environment(\.managedObjectContext, context)`，否则子视图 context 为系统默认空 context，写入不会被 `@FetchRequest` 感知）
- 列表用 `@FetchRequest`，编辑器用 `@StateObject ViewModel(context:)`；ViewModel 保存后 `try? CoreDataStack.shared.save()` 触发 `NSManagedObjectContextDidSave` → SwiftUI 自动刷新 FetchRequest

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

**EntryEditor 保存守卫**
- `EntryEditorViewModel.save()` 的"空内容"判断必须 `title.isEmpty && content.isEmpty` 双空才跳过；只看 content 会导致仅填标题的日记被静默丢弃。

**NotebookDetailView 列表样式（Day One 风格）**
- 列表按月分组（`yyyy年M月`，中文），同月内按日合并：`EntryGroup.flatRows` 比较相邻条目的 `年-月-日` 三元组，仅当与上一条不同日时 `showDate=true`。
- 左侧日期列固定宽 36pt：`showDate` 时显示「周X（小灰）+ 日（大白粗体）」垂直排列；续条留空但保持宽度对齐。
- 副标题用 `Text + Text` 拼接：`HH:mm · XX.XX°北, XX.XX°东 · XX°C 天气`，分隔符 `·` 用更暗的 `#5A5A68`。

**暖色主题**
- 颜色：`Color.warmPaper / warmCream / warmLight / warmBrown / warmAccent / warmGray / warmDark`（`Extensions/Color+Warm.swift`）
- 字体：`Font.warmTitle / warmHeadline / warmBody / warmCaption / warmFootnote`（`Extensions/Font+Warm.swift`）
- 卡片样式：`.warmCard()` modifier（`Extensions/View+Extensions.swift`）

## 已知可忽略的 Xcode 日志

详见 `docs/XCODE_KNOWN_LOGS.md`，包括：启动遥测、iCloud 账号缓存提示、键盘辅助栏约束冲突、辅助功能类未找到。CloudKit `CKAccountStatusNoAccount` (134400) 已在代码层面降级处理。
