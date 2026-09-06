# Dayfold iOS 项目功能梳理报告

> 范围:Dayfold 当前代码库(iOS,Swift + SwiftUI + Core Data + CloudKit)
> 目的:回答"应用启动流程 / 核心功能 / CRUD 完整性"三问,并标注已知缺口
> 生成时间:2026-09-05

---

## Q1. 应用打开后,依次进入了哪些视图?

### 1.1 启动序列(冷启动)

```
[LaunchScreen.storyboard]    // 系统启动画面,瞬间闪过
        ↓
[dayfoldApp.WindowGroup]               // App 入口,创建根 Scene
        ↓
[SecurityManager] isLocked = true      // 全局锁状态(默认锁定)
        ↓
[LockScreenView]                       // 密码/生物识别门
        ↓ .onAppear → 若启用 → authenticate()
[SecurityManager.authenticate()]
        ↓ 成功 / 无生物识别 → isLocked = false
[MainTabView] selectedTab = .list      // 主界面(默认 tab)
        ↓ 抽屉入口:右上齿轮按钮 / 右侧空白点击
[DrawerView / SidebarView] (左抽屉,85% 屏宽)  // PHOTO ALBUM 风格三组卡
        ↓ 抽屉内二级页由 DrawerView.presentedTab 控制
[SidebarView+Detail]                   // 二级页容器/路由/占位
```

### 1.2 关键节点说明

- **锁屏分支**:`dayfoldApp.body` 使用 `Group { if securityManager.isLocked } else ...` 分流。无生物识别时,`authenticate()` 直接放行(不卡死)。
- **主界面架构**:`MainTabView` 是 **抽屉式** 而非传统的底部 TabBar。内容区根据 `selectedTab` 切换。
- **默认视图**:`selectedTab = .list` → `HomeView`(笔记本书架,默认 **封面模式**)。
- **封面/列表切换**:`NotebookCoverView`(5 种风格:chevron / triangle / stripes / leather / diagonal)+ 列表模式(`EntryListView`)。
- **进入详情**:点击封面 → `fullScreenCover` → `NotebookDetailView`(月份分组的日记卡片);**列表模式点击只更新 `currentIndex`,不会进入详情(已知缺口)**。
- **新建入口**:`MainTabView` 顶层 sheet + `NotebookDetailView` 内 `+` 按钮 + `CalendarView` 空日期(prefillDate),均推入 `EntryEditorView`。
- **抽屉触发**:仅靠顶部齿轮按钮 + 右侧空白点击,**无 Swipe 手势**。
- **首次启动数据兜底**:`.onAppear` 时调用 `createPresetTags()`(7 个中文预置标签)+ `ensureDefaultNotebook()`(无本则建"我的日记")。

### 1.3 内容区可达性矩阵

| Tab 枚举 | 预期内容 | 实际状态 |
|---|---|---|
| `.list` | HomeView(封面+列表) | ✅ 已实现 |
| `.timeline` | TimelineView(三模式) | ❌ 未挂载,默认 `.list` |
| `.map` | MapView + 标注 | ❌ 未挂载 |
| `.stats` | StatsView | ❌ 未挂载 |
| `.tags` | TagsView | ❌ 未挂载,且 TagsView 无任何入口 |
| `.icloud` | iCloud 同步 | ⚠️ 占位 |
| `.memories` | 回忆 | ⚠️ 占位 |
| `.notifications` | 通知 | ⚠️ 占位 |
| `.privacy` | 隐私 | ⚠️ 占位(指向 SettingsView) |
| `.hiddenAlbum` | 隐藏相册 | ⚠️ 占位 |
| `.trash` | 回收箱 | ⚠️ 占位(TrashView 文件存在,MainTabView 未挂载) |
| `.about` | 关于 | ⚠️ 占位 |

> 结论:抽屉式架构已搭好骨架,但 **9 个内容区只有 1 个(`.list`)真正可达**。

### 1.4 关键文件路径

- `dayfold/dayfold/dayfoldApp.swift:11-34` — 入口分流
- `dayfold/dayfold/Views/MainTabView.swift:38-46` — `selectedTab` 分支(只实现 `.list`)
- `dayfold/dayfold/Views/LockScreenView.swift:61-65` — 锁屏 `.onAppear` 自动认证
- `dayfold/dayfold/Services/SecurityManager.swift:20-26` — 无生物识别时直接放行
- `dayfold/dayfold/Views/HomeView.swift:55-68` — `fullScreenCover` 推 NotebookDetailView
- `dayfold/dayfold/Views/HomeView.swift:168-172` — 列表模式点击只更新 currentIndex(缺口)

---

## Q2. 当前核心功能有哪些?

按"用户能做什么"分类,每条标注关键文件 + 一句话定位。

### 2.1 日记写作

| 功能 | 关键文件 | 说明 |
|---|---|---|
| 富文本编辑器 | `Views/Entry/EntryEditorView.swift` | UITextView 封装(`SelectableTextEditor`),支持格式化工具栏 |
| 格式化工具栏 | `Views/Entry/Components/FormattingToolbar.swift` | 加粗/斜体/标题/列表等 Markdown 快捷键 |
| 图片选择 | `Views/Entry/Components/PhotoLibraryPickerView.swift` | PhotosUI 多选 + 缩略图缓存 |
| 标签选择 | `Views/Entry/Components/TagPicker.swift` | 多对多关联 |
| 自动保存 | `ViewModels/EntryEditorViewModel.swift` | 2s tick + `imagesChanged` 脏标记 |
| 位置/天气自动拉取 | `ViewModels/EntryEditorViewModel.swift:481-497` | 新建时 `fetchLocationAndWeather()` |
| 心情选择 | `EntryEditorView.swift:355-379` | 5 种 emoji:blank/cloudy/sunny/night/sparkle |
| EXIF 元数据采用 | `EntryEditorViewModel.pendingMetadata` | "使用时间和位置?" 弹窗 |

> 死代码:`Views/Entry/Components/MarkdownEditor.swift` — **未被任何视图引用**,可考虑删除。

### 2.2 日记阅读

| 功能 | 关键文件 | 说明 |
|---|---|---|
| 全部列表 | `Views/Entry/EntryListView.swift` | 全文搜索 + 收藏 + 标签筛选 |
| 笔记本详情 | `Views/NotebookDetailView.swift` | 月份分组 + Day One 风格左日期列 + 左滑删除 |
| 日历视图 | `Views/Timeline/CalendarView.swift` + `MonthGridView` | 空日期点击新建 |
| 照片墙 | `Views/Timeline/PhotoWallView.swift` | 按图片聚合,大图 2x2 占位 |
| 时间线(三模式切换) | `Views/Timeline/TimelineView.swift` | 列表/日历/照片墙 Picker ⚠️ **当前不可达(只能 `.list`)** |
| 往年今日 | `Views/Timeline/OnThisDaySection.swift` | 历史回顾 + `OnThisDayYearRow` |
| 地图视图 | `Views/Map/MapView.swift` + `MapKitView.swift` | 反向地理编码标注 ⚠️ **当前不可达** |
| 日记详情 | `Views/Entry/EntryDetailView.swift` | 图文混排(正则切分)+ 收藏 + 导出 menu |
| 搜索/筛选 | `ViewModels/EntryListViewModel.swift:49-73` | CONTAINS[cd] 全文(title OR content)+ 收藏 + 标签 AND |

### 2.3 笔记本管理

| 功能 | 关键文件 | 说明 |
|---|---|---|
| 书架(封面模式) | `Views/HomeView.swift` + `NotebookCoverView` | 5 种封面风格,TabView 翻页 |
| 列表模式 | `EntryListView` | 切换后只更新 currentIndex ⚠️ 列表模式点不开 |
| 创建/删除笔记本 | `Models/Notebook+Ext.swift` | 含批量软删 `deleteWithEntriesToTrash` |
| 默认笔记本保障 | `CoreDataStack.ensureDefaultNotebook()` | 启动时若无默认本则补建 |
| 预置标签 | `CoreDataStack.createPresetTags()` | 启动时创建 7 个中文标签 |

### 2.4 标签管理

| 功能 | 关键文件 | 说明 |
|---|---|---|
| 标签列表 | `Views/Tags/TagsView.swift` | ⚠️ **未挂载,无入口** |
| 标签编辑器 | `Views/Tags/TagEditorView.swift` | 名称 + 10 色色板 + 12 图标 |
| CRUD API | `ViewModels/TagManagerViewModel.swift` | create/update/delete/move 完整 |

### 2.5 媒体与位置

| 功能 | 关键文件 | 说明 |
|---|---|---|
| 图片落盘 | `Services/MediaService.swift` | UUID.jpg + 100x100 缩略图 + `isValidFilename` 防 path traversal |
| 照片库读取 | `Services/PhotoLibraryService.swift` | 只读 + 按日分组 + 反向地理编码 |
| 定位/反地理编码 | `Services/LocationService.swift` | `@MainActor`,100m 精度 |
| 天气 | `Services/WeatherService.swift` | WeatherKit |

### 2.6 导出与分享

| 功能 | 关键文件 | 说明 |
|---|---|---|
| 图片卡片 | `Services/CardExporter.swift` | `ImageRenderer` scale 3.0,保存到相册 |
| PDF(A4) | `Services/EntryPDFExporter.swift` | `UIGraphicsPDFRenderer`,图片独立页 |
| Markdown(Obsidian YAML) | `Services/EntryMarkdownExporter.swift` | front-matter(title/date/modified/tags/location/mood) |
| 分享面板 | `Views/Common/ExportShareSheet.swift` | 系统 `UIActivityViewController` |
| 卡片预览 | `Views/Entry/EntryCardPreviewSheet.swift` | 渲染 `EntryCardView` → 保存/分享 |

### 2.7 数据与安全

| 功能 | 关键文件 | 说明 |
|---|---|---|
| Core Data + CloudKit | `Services/CoreDataStack.swift` | `NSPersistentCloudKitContainer`,无账号 134400 降级本地 |
| 软删/回收站 | `Models/Entry+Ext.swift` + `Views/Entry/TrashView.swift` | `deletedAt` 时间戳 |
| 人脸识别锁 | `Services/SecurityManager.swift` | Face ID,无生物识别时放行 |
| Markdown ↔ AttributedString | `Services/RichTextMarkdownParser.swift` | 详情页渲染 + 编辑器读写 + 防内存爆炸 |

### 2.8 统计(开发中)

| 功能 | 关键文件 | 说明 |
|---|---|---|
| 数据面板 | `Views/StatsView.swift` + `StatsViewModel` | 总览/连续天数/带图带位置比例/标签分布 ⚠️ **未挂载** |
| 连续天数计算 | `StatsViewModel.currentStreak` | 反向遍历 `Set<Date>` |

---

## Q3. 日记的增删改查是否完整?

### 3.1 维度对照表

| 维度 | 已实现 | 缺口 / 风险 |
|---|---|---|
| **Create 创建** | 3 个入口(笔记本内 `+` / 日历空日期 / TimelineView);自动 fetch 位置 + 天气;`prefillDate` 支持 | `EntryListView` 无 `+` 按钮;`MainTabView.showingNewEntry` 是死代码(无 Button 绑定) |
| **Read 读取** | 4 种列表(全部/笔记本/三模式时间线/OnThisDay)+ 详情(图文混排/收藏/导出) | 详情页未展示 mood、createdAt、updatedAt |
| **Update 更新** | 自动保存 2s tick + 脏标记(`imagesChanged`)+ 双路径 reconcile | 编辑取消时新增的图片文件 **不会清理**(孤儿风险) |
| **Delete 删除** | 软删(右键/左滑/整本)+ 永久删除同步清理 MediaAsset + Location | `EntryListView` 无左滑删除;无启动时 orphan 文件扫描清理任务 |
| **图片 CRUD** | MediaService 有 path traversal 防护;永久删除时同步删文件;JPEG 0.8 压缩 | 编辑取消的孤儿文件;无启动清理任务;`MediaType.video` 枚举存在但无 video 写入 |
| **Tag CRUD** | API(create/update/delete/move)完整;关系 Nullify 自动;多对多关联 | ⚠️ **UI 完全不可达**:TagsView 无挂载入口,SidebarTab 无 tag 项,MainTabView 无 Tag tab,Drawer 无 tag 项 |
| **搜索/筛选** | `EntryListViewModel.filterPredicate` 全文(title+content OR)+ 收藏 + 标签 AND | 其他视图无搜索(Timeline / NotebookDetailView);无笔记本/日期/心情筛选 |

### 3.2 软删/恢复/永久删除细节

- **软删**:`Entry.moveToTrash()` 写 `deletedAt` 时间戳(`Models/Entry.swift:35-39`)。
- **恢复**:`TrashView` 左滑 → `NotebookPickerSheet` 选本 → `Entry.restore()` 清空 `deletedAt`。
- **永久删除**:`TrashView` 右滑 → 同步清理 `MediaAsset` 文件 + `Location` 实体 + `Entry`(避免磁盘孤儿)。
- **整本删除**:`Notebook.deleteWithEntriesToTrash(in:)` 批量软删(走 `Entry.moveToTrash`)。

### 3.3 自动保存机制

- **tick**:`EntryEditorViewModel.startAutoSave()` 每 2 秒触发一次。
- **脏标记**:`imagesMap.didSet`(仅当 `isLoadingImages == false` 时触发,避免初始化期间误保存)。
- **双路径**:
  - `save(isAutoSave: true)` → 只补建/排序,**不删除**(防 auto-save 与图片持久化 in-flight 任务竞态)
  - `save(isAutoSave: false)` → 手动保存,全量 reconcile,删除正文中不存在的旧 `MediaAsset`
- **取消行为**:新建取消会清理图+entry+location;编辑取消仅恢复 entry 字段,**新增未提交的图片文件不会被清理** → 孤儿风险。

### 3.4 其他发现的瑕疵

- `MainTabView` 顶层无显式 `+` 按钮,`showingNewEntry` 是死代码(状态变量 + sheet 已就位,无任何 Button 绑定)。
- `HomeView` 封面模式的 `+` 圆按钮调的是 `addNotebook()`(加笔记本),不是新建日记。
- `EntryDetailView` 的 toolbar 依赖外层 `NavigationStack` 包裹(否则导出 menu 不可见)。
- 编辑器内的 **AI 按钮(`sparkles`)** 当前 `disabled`;**附件按钮(`paperclip`)** 空 action。
- 详情页未展示 mood、updatedAt、createdAt 单独显示(`EntryHeader` 只有日期/位置/天气/标签 chip)。
- 5 个抽屉二级页(iCloud/Memories/Notifications/Hidden Album/About)是 `DrawerPlaceholderDetail` 占位。
- `PhotoLibraryPickerView` 的"所有媒体"筛选 UI 渲染但无功能(注释自承"暂不做真实筛选")。
- `MediaType.video` 枚举已定义但全代码链无人创建 video 类型 `MediaAsset`。

---

## 建议优先级(缺口排序)

按 **用户感知度** × **修复成本** 排序,帮助决定下一步。

### 高优先级(用户立刻能感知 + 修复成本低)

| 缺口 | 感知度 | 修复成本 | 建议 |
|---|---|---|---|
| `MainTabView` 9 个内容区只挂 1 个 | 抽屉里大部分点击无反应 | 低(补 `switch selectedTab` 分支) | **立刻补** |
| TagsView 无入口 | 用户找不到标签管理 | 极低(挂一个 tab 或 Drawer 项) | **立刻补** |
| `EntryListView` 无 `+` 按钮 + `MainTabView.showingNewEntry` 死代码 | 用户在主列表/全部列表里写不了日记 | 低(补 toolbar 按钮 + Button 绑定) | **立刻补** |
| `HomeView` 列表模式点击不进入详情 | 列表模式用不了 | 低(区分"封面点击" vs "列表点击" 语义) | **立刻补** |

### 中优先级(可感知但需要一定工作量)

| 缺口 | 感知度 | 修复成本 | 建议 |
|---|---|---|---|
| 编辑取消的孤儿图片 | 长期累积浪费磁盘 | 低(`cancel()` 里删 `imagesMap` 新增项) | 一并补 |
| 启动 orphan 文件扫描 | 长期累积浪费磁盘 | 中(遍历 `Documents/Media` 比对 Core Data) | 加一个启动任务 |
| `EntryListView` 无左滑删除 | 与 `NotebookDetailView` 设计语言不一致 | 低(套 `.swipeActions`) | 一并补 |
| 详情页 mood/createdAt 不展示 | 信息不完整 | 极低(加 `EntryHeader` item) | 一并补 |
| `Privacy` / `Hidden Album` / `Trash` 抽屉二级页占位 | 用户点击进入空白页 | 中(接入 `SettingsView` / `TrashView` 已有组件) | 一并补 |

### 低优先级(锦上添花 / 暂缓)

| 缺口 | 感知度 | 修复成本 | 建议 |
|---|---|---|---|
| `MarkdownEditor.swift` 死代码 | 无用户感知 | 极低(删除文件) | 清理 |
| AI 按钮 disabled | 用户预期落空 | 高(需接入 LLM) | 暂缓 |
| 附件按钮空 action | 用户预期落空 | 中(需接 storage) | 暂缓 |
| `iCloud` / `Memories` / `Notifications` / `About` 占位 | 用户点击进入空白页 | 各异 | 按产品决策排期 |
| `MediaType.video` 无写入路径 | 用户期望录视频 | 中(需视频压缩/转码) | 暂缓 |
| 其他视图无搜索(Timeline / NotebookDetailView) | 中等 | 中(复用 `filterPredicate`) | 视需求 |

---

## 总体判断

- **架构完整度**:高。Core Data + CloudKit 降级、自动保存、软删恢复、导出三件套(图片/PDF/Markdown)、安全锁、富文本编辑器都已落地。
- **功能完成度**:中。核心模块(Timeline/Map/Tags/Stats)代码已写好但 **未挂载到导航**,抽屉式架构缺一半实现;TagsView 完全不可达。
- **数据安全度**:中。永久删除路径覆盖完整,但 **编辑取消 + 启动扫描** 两个口子会让磁盘留孤儿;`EntryListView` 无左滑删除是设计一致性缺口。
- **下一步建议**:先打通导航(挂 4 个 tab + TagsView 入口 + `MainTabView.showingNewEntry` 按钮绑定),再做孤儿清理。AI / 附件 / 视频按产品决策排期。

---

## Critical Files(后续如需动手补缺口的最高优先级目标)

- `dayfold/dayfold/Views/MainTabView.swift` — 补 `selectedTab` 分支 + `showingNewEntry` 按钮绑定
- `dayfold/dayfold/Views/Entry/EntryListView.swift` — 加 `+` toolbar + 左滑删除
- `dayfold/dayfold/ViewModels/EntryEditorViewModel.swift` — `cancel()` 补删图片孤儿
- `dayfold/dayfold/Services/MediaService.swift` — 加 `reconcileOrphans()` 启动清扫
- `dayfold/dayfold/Views/HomeView.swift` — 列表模式点击进入详情
