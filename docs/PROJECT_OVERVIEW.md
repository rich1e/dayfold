# Dayfold 项目梳理（功能 / 页面 / UI 交互流程）

> 生成日期：2026-07-27
> 依据：`dayfold/dayfold/` 源码实际实现（非设计文档），所有结论可回溯到文件与符号。
> 图例：实线箭头 = 页面跳转；虚线箭头 = 数据流；🚧 = 代码中存在但未接入 UI / 占位未实现。

---

## 一、功能清单

### 1.1 功能全景图

```mermaid
mindmap
  root((Dayfold<br/>日记 App))
    日记核心
      新建日记
      编辑日记
      Markdown 正文
      标题可选
      自动保存 2s
      收藏标记
      软删除回收站
      心情字段 🚧
    富媒体
      图片附件 最多10张
      缩略图生成
      九宫格浏览
      全屏看图
      视频类型预留 🚧
    上下文元数据
      定位 经纬度
      反向地理编码 城市·区域
      WeatherKit 天气
      温度 / 天气图标
    组织与检索
      标签 多对多
      7个预置标签
      标题正文关键词搜索
      收藏筛选 🚧
      标签筛选 🚧
    多视图浏览
      笔记本封面墙
      月分组时间轴
      月历 + 圆点
      照片墙 瀑布流
      地图 + 聚合标注
    分享导出
      日记卡片渲染 3x
      保存到系统相册
      系统分享面板
    数据与安全
      Core Data 持久化
      CloudKit 同步
      无账号降级本地
      Face ID / Touch ID 锁屏
    未完成
      数据统计 🚧
      设置页 🚧
```

### 1.2 功能 → 代码依据

| 功能 | 关键实现 |
| --- | --- |
| 日记 CRUD | `Models/Entry.swift`（`create` / `moveToTrash` / `restore`）、`EntryEditorViewModel.save()` |
| 自动保存 | `EntryEditorViewModel.startAutoSave()`，`Timer` 间隔 2.0s |
| 图片附件 | `Services/MediaService.swift`（`saveImage` / `loadImage` / `generateThumbnail`），落盘 `Documents/Media/{UUID}.jpg`，DB 仅存 `filename` |
| 定位 | `Services/LocationService.swift`，`kCLLocationAccuracyHundredMeters` + `reverseGeocode` |
| 天气 | `Services/WeatherService.swift`，WeatherKit `currentWeather` |
| 标签 | `Models/Tag.swift`（`presetTags()` 7 个）、`TagManagerViewModel` |
| 收藏 | `Entry.isFavorite`，入口：详情页星标、列表长按菜单、照片墙长按菜单 |
| 回收站 | `Entry.deletedAt` 软删除；`TrashView` 恢复 / 彻底删除 / 全部删除 |
| 卡片导出 | `Services/CardExporter.swift`，`ImageRenderer(scale: 3.0)` + `PHAssetChangeRequest` |
| CloudKit | `Services/CoreDataStack.swift`，容器 `iCloud.com.Yuqi.dayfold`，错误 134400 降级本地 |
| 生物识别锁 | `Services/SecurityManager.swift`，`LAContext.deviceOwnerAuthenticationWithBiometrics` |

### 1.3 已知未完成项（重要）

| 项 | 现状 |
| --- | --- |
| **笔记本（Notebook）** | 只是 `HomeView.swift` 内的 Swift `struct` + `@State` 数组，**没有 Core Data 实体**；`NotebookDetailView` 的 `@FetchRequest` 不带 notebook 谓词，展示的是**全部日记**。App 重启后笔记本列表丢失。 |
| **FormattingToolbar / MarkdownEditor** | 组件已写好（加粗、斜体、列表、有序列表、引用、链接、待办 7 个按钮），**未接入** `EntryEditorView`。编辑器实际键盘栏只有 4 个键，其中 `paperclip`、`textformat` 是空闭包。 |
| **TagPicker** | 组件与 `EntryEditorViewModel.addTag/removeTag` 均存在，**编辑器未挂载**，无法在写日记时选标签。 |
| **标签新建** | `TagManagerViewModel.createTag` 已实现，`TagsView` **无 "+" 入口**，只能编辑已有标签。 |
| **列表筛选** | `EntryListViewModel.showFavoritesOnly` / `selectedTags` 已实现，`EntryListView` **无 UI 开关**。 |
| **心情** | `Entry.mood` 字段 + `wrappedMood` 存在，编辑器无输入入口。 |
| **视频** | `MediaAsset.MediaType.video` 已枚举，`MediaService` 只处理图片。 |
| **数据统计 / 设置** | 侧边栏可点，落到 `PlaceholderView`（"即将推出"）。 |
| **PhotoWallView 点击** | `TimelineView` 未传 `onSelectEntry`，点击无响应；contextMenu "编辑条目" 是空实现。 |

---

## 二、页面清单与导航结构

### 2.1 页面地图

```mermaid
graph TD
    App["dayfoldApp<br/>@StateObject SecurityManager"]
    App -->|"isLocked == true"| Lock["LockScreenView<br/>Face ID 解锁"]
    App -->|"isLocked == false"| Main["MainTabView<br/>根容器 · drawerOpen"]
    Lock -.->|"authenticate() 成功"| Main

    Main --- Drawer["DrawerView / SidebarView<br/>宽 85% · SidebarTab"]

    Drawer -->|".list"| Home["HomeView<br/>笔记本封面墙 / 列表"]
    Drawer -->|".photos"| List["EntryListView<br/>全部日记 + 搜索"]
    Drawer -->|".map"| Map["MapView<br/>地图 + 聚合"]
    Drawer -->|".trash → showingTrash"| Trash["TrashView (sheet)"]
    Drawer -->|".stats"| PH1["PlaceholderView<br/>数据统计 🚧"]
    Drawer -->|".settings"| PH2["PlaceholderView<br/>设置 🚧"]

    Home -->|"fullScreenCover<br/>showDetail"| NB["NotebookDetailView<br/>按月分组时间轴"]

    NB -->|"sheetMode = .photos"| PW["PhotoWallView"]
    NB -->|"sheetMode = .calendar"| Cal["CalendarView"]
    NB -->|"sheetMode = .newEntry"| Editor["EntryEditorView"]
    NB -->|"sheetMode = .entryDetail"| Detail["EntryDetailView"]

    List -->|"NavigationLink"| Detail
    Map -->|"detailEntry (fullScreenCover)"| Detail

    Cal --- BS["EntryBottomSheet<br/>三档抽屉 80/320/85%"]
    BS -->|"NavigationLink"| Detail
    BS -->|"plus.circle.fill"| Editor
    Cal --- MG["MonthGridView<br/>月历网格 + 圆点"]

    Detail -->|"activeSheet = .edit"| Editor
    Detail -->|"activeSheet = .card"| Card["EntryCardPreviewSheet"]
    Card -->|"showingShareSheet"| Share["ShareSheet<br/>UIActivityViewController"]

    Editor -->|"showingImagePicker"| MP["MediaPicker<br/>PhotosPicker ≤10"]

    Tags["TagsView + TagEditorView<br/>🚧 无导航入口"]

    style PH1 stroke-dasharray: 5 5
    style PH2 stroke-dasharray: 5 5
    style Tags stroke-dasharray: 5 5
```

### 2.2 页面职责表

| 页面 | 文件 | 呈现方式 | 职责 |
| --- | --- | --- | --- |
| LockScreenView | `Views/LockScreenView.swift` | 根级替换 | 生物识别解锁 |
| MainTabView | `Views/MainTabView.swift` | 根容器 | 抽屉 + 内容区，`selectedTab` 驱动 |
| DrawerView | `Views/SidebarView.swift` | 左侧 85% | 6 个 `SidebarTab` 导航项 |
| HomeView | `Views/HomeView.swift` | 内容区 | 笔记本封面墙（TabView 翻页）/ 列表模式 |
| NotebookDetailView | `Views/NotebookDetailView.swift` | fullScreenCover | Day One 风格月分组时间轴 |
| EntryListView | `Views/Entry/EntryListView.swift` | 内容区 | 全部日记卡片列表 + `.searchable` |
| MapView | `Views/Map/MapView.swift` | 内容区 | MKMapView + 聚合 + 搜索 + 底部卡片 |
| TrashView | `Views/Entry/TrashView.swift` | sheet | 回收站，按 `deletedAt` 同日分组 |
| EntryDetailView | `Views/Entry/EntryDetailView.swift` | push / sheet | 日记详情 + 收藏 / 卡片 / 编辑 |
| EntryEditorView | `Views/Entry/EntryEditorView.swift` | sheet | 新建 / 编辑，自动保存 |
| EntryCardPreviewSheet | `Views/Entry/EntryCardPreviewSheet.swift` | sheet | 卡片预览 → 存相册 / 分享 |
| CalendarView | `Views/Timeline/CalendarView.swift` | sheet | 月历 + 底部抽屉 |
| MonthGridView | `Views/Timeline/MonthGridView.swift` | 子视图 | 7 列日期网格，圆点最多 3 个 + `N+` |
| EntryBottomSheet | `Views/Timeline/EntryBottomSheet.swift` | 叠加层 | 三档高度当日条目抽屉 |
| PhotoWallView | `Views/Timeline/PhotoWallView.swift` | sheet | 3 列瀑布流，收藏项占 2 列大格 |
| TimelineView | `Views/Timeline/TimelineView.swift` | 🚧 无入口 | 列表 / 日历 / 照片墙分段切换容器 |
| TagsView | `Views/Tags/TagsView.swift` | 🚧 无入口 | 标签列表，重排 / 删除 / 编辑 |

---

## 三、UI 交互流程

### 3.1 启动与解锁

```mermaid
sequenceDiagram
    participant U as 用户
    participant App as dayfoldApp
    participant SM as SecurityManager
    participant LS as LockScreenView
    participant M as MainTabView

    App->>SM: init(isLocked = true, isEnabled = true)
    App->>LS: isLocked → 渲染锁屏
    LS->>LS: .onAppear
    alt isEnabled == true
        LS->>SM: authenticate() 自动触发
    else 手动
        U->>LS: 点击「解锁」按钮 (faceid)
        LS->>SM: authenticate()
    end
    SM->>SM: LAContext.deviceOwnerAuthenticationWithBiometrics
    alt 成功 / 设备不支持生物识别
        SM-->>App: isLocked = false
        App->>M: 切换到 MainTabView
        M->>M: coreDataStack.createPresetTags()（首次写 7 个标签）
    else 失败
        SM-->>LS: print("Authentication failed")
        Note over LS: 无错误提示 UI，可再次点按重试
    end
```

### 3.2 抽屉导航

```mermaid
stateDiagram-v2
    [*] --> 内容区显示
    内容区显示 --> 抽屉打开 : 点击左上 gearshape<br/>drawerOpen.toggle()<br/>spring(0.38, 0.82)
    抽屉打开 --> 内容区显示 : 点击遮罩<br/>drawerOpen = false
    抽屉打开 --> 切换Tab : 点击 DrawerRow
    切换Tab --> 内容区显示 : selectedTab = tab<br/>isOpen = false
    切换Tab --> 回收站Sheet : tab == .trash<br/>onChange → showingTrash = true
    回收站Sheet --> 内容区显示 : xmark / dismiss()

    note right of 抽屉打开
        内容区 offset(x: 屏宽*0.85)
        无滑动手势，仅按钮 + 遮罩点击
    end note
```

### 3.3 写日记主流程（新建）

```mermaid
sequenceDiagram
    participant U as 用户
    participant Src as 入口页
    participant E as EntryEditorView
    participant VM as EntryEditorViewModel
    participant LS as LocationService
    participant WS as WeatherService
    participant MS as MediaService
    participant DB as CoreDataStack

    Note over Src: 3 个入口<br/>NotebookDetail 底部 +<br/>MapView 底部 +<br/>EntryBottomSheet plus.circle.fill(带 prefillDate)
    U->>Src: 点击 +
    Src->>E: sheet(EntryEditorView(context:, prefillDate:))
    E->>VM: init → startAutoSave() 每 2s
    VM->>LS: requestLocation()
    LS-->>VM: currentLocation + placeName（Combine .first()）
    VM->>WS: fetchWeatherIfPossible(location)
    WS-->>VM: WeatherData(温度/condition/symbolName)
    Note over E: metaBar 只读展示 地点 · 天气 · 温度

    U->>E: 输入标题（submitLabel .next → 焦点跳正文）
    U->>E: 输入正文（TextEditor minHeight 320）

    opt 添加图片
        U->>E: 键盘栏 photo.on.rectangle → showingImagePicker
        E->>MS: MediaPicker(PhotosPicker, ≤10 张)
        MS-->>VM: images.append → imagesChanged = true
        Note over E: imagePreviewRow 72×72 缩略图<br/>右上 xmark.circle.fill 删除
    end

    loop 每 2 秒
        VM->>VM: save()
        alt title 与 content 双空
            VM-->>VM: return false（跳过）
        else
            VM->>DB: Entry.create / 更新字段 + Location + Tag
            alt imagesChanged == true
                VM->>MS: 删旧文件 + saveImage 全量重建 MediaAsset
            end
            VM->>DB: save() → NSManagedObjectContextDidSave
            DB-->>Src: @FetchRequest 自动刷新
        end
    end

    U->>E: 点击「完成」
    E->>VM: await save()
    E->>E: dismiss()
    Note over E: 无「取消」按钮；<br/>showingSaveError 已声明但无触发路径
```

### 3.4 浏览与查看日记

```mermaid
flowchart TD
    Start([进入 App]) --> Home[HomeView 封面墙]

    Home -->|"顶部右侧按钮<br/>isListMode 切换"| HomeList[列表模式 NotebookListRow]
    Home -->|"TabView 左右滑动"| Home
    Home -->|"点击封面<br/>showDetail = true"| NB[NotebookDetailView]
    Home -->|"底部 + / trash<br/>confirmDelete 二次确认"| Home

    NB -->|"点击行"| Detail[EntryDetailView]
    NB -->|"左滑 SwipeToDeleteRow<br/>entry.moveToTrash()"| NB
    NB -->|"顶栏 photo.on.rectangle"| PW[PhotoWallView sheet]
    NB -->|"顶栏 calendar"| Cal[CalendarView sheet]
    NB -->|"chevron.left"| Home

    Cal -->|"chevron.left / right<br/>或月历左右滑动 >50pt"| Cal
    Cal -->|"点击日期格<br/>selectedDate = startOfDay"| BS[EntryBottomSheet 更新]
    BS -->|"点摘要条 / 拖拽<br/>80 ↔ 320 ↔ 85%屏高"| BS
    BS -->|"点击条目 NavigationLink"| Detail
    BS -->|"photo.on.rectangle<br/>viewMode = .photoWall"| PW

    PW -->|"长按 contextMenu<br/>收藏 / 取消收藏"| PW

    Detail -->|"星标 toggleFavorite()<br/>即时生效无弹窗"| Detail
    Detail -->|"编辑"| Editor[EntryEditorView]
    Detail -->|"square.and.arrow.up.on.square"| Card[EntryCardPreviewSheet]
    Detail -->|"点击 MediaGrid 图片"| Full[FullscreenImageView]

    Editor -.->|"onDismiss → loadImages()"| Detail

    Search[EntryListView] -->|".searchable 搜索日记<br/>标题/正文 CONTAINS"| Search
    Search -->|"NavigationLink"| Detail
    Search -->|"长按 contextMenu<br/>删除 / 收藏"| Search
```

### 3.5 地图页交互

```mermaid
sequenceDiagram
    participant U as 用户
    participant MV as MapView
    participant VM as MapViewModel
    participant MK as MapKitView (MKMapView)
    participant Card as MapEntryCard

    MV->>VM: init → reload()
    VM->>VM: predicate: deletedAt == nil AND location != nil
    VM-->>MK: entries（订阅 ContextDidSave 自动 reload）
    MK->>MK: applyInitialRegion<br/>boundingRegion(span×1.4) 或 fallback 上海

    alt 无带位置日记
        MV->>U: emptyState「还没有带位置的日记」
    end

    U->>MV: 在 MapSearchBar 输入关键词
    MV->>VM: query 变化
    VM->>VM: visibleEntries 匹配 title/content/placeName（小写子串）
    alt 无结果
        MV->>U: 胶囊提示「无匹配结果」
    end
    U->>MV: 点 xmark.circle.fill → query = ""

    alt 点击单个 marker
        U->>MK: 点击 EntryPin
        MK->>MV: onSelect([entry])
    else 点击聚合簇
        U->>MK: 点击 cluster
        MK->>MK: memberAnnotations → objectID → existingObject(with:)
        MK->>MV: onSelect(entries)
    end
    MV->>Card: selectedEntries 非空 → 展示卡片
    Note over Card: 单条：直接卡片<br/>多条：TabView .page，高 140

    alt 打开详情
        U->>Card: 点击卡片 → onOpen(entry)
        Card->>MV: detailEntry = EntryRef
        MV->>U: fullScreenCover(EntryDetailView) + 「关闭」
    else 关闭卡片
        U->>Card: 下滑 > 50pt → onDismiss()
        Card->>MV: selectedEntries = []
    end

    U->>MV: 底部 + → showingNewEntry = true（由 MainTabView 弹编辑器）
```

### 3.6 删除与恢复（软删除生命周期）

```mermaid
stateDiagram-v2
    [*] --> 正常 : Entry.create()<br/>needsSync = true
    正常 --> 回收站 : moveToTrash()<br/>deletedAt = Date()
    note right of 正常
        入口：
        · NotebookDetailView 左滑删除
        · EntryListView 长按 → 删除
    end note

    回收站 --> 正常 : TrashView 右滑「恢复」<br/>restore() → deletedAt = nil
    回收站 --> [*] : TrashView 左滑「彻底删除」<br/>或「全部删除」+ confirmationDialog

    note right of 回收站
        列表谓词 deletedAt != nil
        按 deletedAt 倒序，同日合并分组
    end note

    note left of [*]
        permanentlyDelete：
        1. 删 MediaAsset + MediaService.deleteImage 磁盘文件
        2. 删 Location
        3. 删 Entry
        4. context.save()
    end note
```

### 3.7 卡片导出与分享

```mermaid
sequenceDiagram
    participant U as 用户
    participant D as EntryDetailView
    participant C as EntryCardPreviewSheet
    participant CE as CardExporter
    participant PH as PhotoKit

    U->>D: 点击 square.and.arrow.up.on.square
    D->>C: activeSheet = .card → sheet
    C->>U: 预览 EntryCardView（宽 340，头部日期/天气/位置 + 正文 + ≤3 张图 + 标签 + Dayfold 水印）

    alt 保存到相册
        U->>C: 点「保存到相册」→ isSaving = true
        C->>CE: render(EntryCardView) — ImageRenderer scale 3.0
        alt 渲染失败
            CE-->>C: nil → saveResult = .failure
            C->>U: alert「保存失败 / 生成图片时出错，请重试」
        else
            CE->>PH: requestAuthorization(.addOnly) + PHAssetChangeRequest
            alt 成功
                PH-->>C: saveResult = .success
                C->>U: alert「已保存 / 卡片已保存到系统相册」
            else 无权限
                PH-->>C: saveResult = .noPermission
                C->>U: alert「无相册权限 / 请在设置→隐私→照片中允许」
            end
        end
        U->>C: 点「确定」→ saveResult = nil
    else 系统分享
        U->>C: 点「分享」
        C->>CE: render(...)
        CE-->>C: shareImage → showingShareSheet = true
        C->>U: ShareSheet(UIActivityViewController)
    end

    U->>C: 点「关闭」→ dismiss()
```

### 3.8 数据流与刷新机制

```mermaid
flowchart LR
    subgraph 视图层
        FR["@FetchRequest<br/>感知集合增删"]
        OO["@ObservedObject NSManagedObject<br/>感知行内属性变化"]
    end

    subgraph ViewModel
        EVM[EntryEditorViewModel]
        TVM[TimelineViewModel]
        MVM[MapViewModel]
        LVM[EntryListViewModel]
    end

    subgraph 服务层
        CDS[CoreDataStack.shared]
        MS[MediaService]
        LSV[LocationService]
        WS[WeatherService]
    end

    subgraph 存储
        SQL[(SQLite<br/>NSPersistentCloudKitContainer)]
        FS[(Documents/Media<br/>UUID.jpg)]
        CK[(CloudKit<br/>iCloud.com.Yuqi.dayfold)]
    end

    EVM -->|save| CDS
    LVM -->|moveToTrash / toggleFavorite| CDS
    CDS --> SQL
    SQL <-->|"账号可用时双向；<br/>134400 降级本地"| CK
    EVM -->|saveImage / deleteImage| MS
    MS --> FS
    EVM -.->|读| LSV
    EVM -.->|读| WS

    CDS -->|"NSManagedObjectContextDidSave 通知"| FR
    CDS -->|"同一通知"| MVM
    MVM -->|reload| FR
    SQL -.->|"NSPersistentStoreRemoteChange"| CDS

    FR --> OO

    note1["约定：<br/>1. sheet / fullScreenCover 内必须再次<br/>.environment(\\.managedObjectContext, context)<br/>2. 行内属性变化需 @ObservedObject<br/>3. 缩略图用 .task(id: thumbnailSourceID)"]
```

---

## 四、关键交互约定（避免踩坑）

| 约定 | 原因 |
| --- | --- |
| `sheet` / `fullScreenCover` 内必须再次注入 `managedObjectContext` | 否则子视图拿到系统默认空 context，写入不被 `@FetchRequest` 感知 |
| 行内属性变化的视图声明 `@ObservedObject var entry: Entry` | `@FetchRequest` 只感知集合增删。已改造：`EntryCard`、`EntryHeader`、`TagRow`、`EntryDetailView` |
| 用 `.sheet(item:)` 而非 `.sheet(isPresented:)` + 独立 `@State` 日期 | 避免 SwiftUI 同帧捕获旧值导致 `prefillDate` 失效 |
| `save()` 空内容判定必须 `title.isEmpty && content.isEmpty` 双空 | 只判 content 会静默丢弃"只填标题"的日记 |
| `MapKitView` 用 `NSManagedObjectID` 而非直接持有 `NSManagedObject` | 避免跨线程持有托管对象 |
| `MediaService.isValidFilename` 拒绝 `..` `/` `\` `:` | 防路径穿越 |

---

## 五、建议的下一步（按影响面排序）

1. **笔记本落地为 Core Data 实体** —— 当前是纯 `@State`，重启丢失，且 `NotebookDetailView` 展示的是全部日记而非本笔记本的日记。这是最大的功能性缺口。
2. **接入 `FormattingToolbar` + `TagPicker` 到 `EntryEditorView`** —— 组件已完成，只需挂载，即可解锁 Markdown 编辑与写作时打标签。
3. **给 `TagsView` 加导航入口和 "+" 新建按钮** —— `createTag` 已实现，页面目前从任何路径都到不了。
4. **`EntryListView` 暴露收藏 / 标签筛选 UI** —— ViewModel 已支持。
5. **补 `EntryEditorView` 的取消按钮与保存失败提示** —— `showingSaveError` 已声明但无触发路径，错误被 `try?` 吞掉。
