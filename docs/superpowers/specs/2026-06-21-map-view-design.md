# 全局地图页面设计

- **日期**：2026-06-21
- **目标**：将 `SidebarTab.map` 的占位页替换为真正的地图视图，跨笔记本展示所有带位置的日记，支持搜索过滤、按位置聚合 pin、点击 pin 弹出底部卡片、右下添加日记。
- **参考 UI**：iOS Apple Maps 风格（聚合气泡上显示数字），但底部不出现「今天/日记本/更多」分段栏。

## 1. 范围

**包含**：

- 全局地图视图，展示所有 `isDeleted == false && location != nil` 的 `Entry`。
- 地图视图顶部内嵌搜索框，按 `placeName / title / content` 包含匹配过滤 pin。
- 使用 `MKMapView` + `clusteringIdentifier` 自动聚合 pin。
- 点击 pin / 聚合气泡 → 底部上浮卡片列出对应日记，点击卡片打开 `EntryDetailView`。
- 右下浮动「＋」按钮 → 弹出 `EntryEditorView`（沿用现有创建流程，自动抓当前定位）。
- 空态文案。

**不包含**：

- 地址逆地理编码 / 第三方地图。
- 复杂的地图样式定制。
- 路线规划、距离测量等高级地图功能。
- 参考图底部「今天/日记本/更多」分段栏。

## 2. 数据流

```
CoreData ──fetch──> MapViewModel.entries: [Entry]
                          │
                          ├── visibleEntries = entries filtered by query
                          │
                          ▼
                  MapKitView (UIViewRepresentable)
                          │
            user taps pin │
                          ▼
              selectedEntries: [Entry]
                          │
                          ▼
                   MapEntryCard (overlay)
                          │
              tap a card  │
                          ▼
                   EntryDetailView (push)
```

- `MapViewModel` 是 `@MainActor ObservableObject`，启动时一次性 `NSFetchRequest` 拉取所有带位置的未删除日记；通过 `NotificationCenter` 监听 `NSManagedObjectContextDidSave` 增量刷新。
- 搜索在内存里过滤：`query.isEmpty ? entries : entries.filter { contains query }`。
- pin 来源是 `visibleEntries`。每次 `visibleEntries` 变更，`MapKitView` 在 `updateUIView` 里 diff（按 `entry.objectID`）增删 annotations。

## 3. 组件拆分

| 文件 | 类型 | 职责 |
|---|---|---|
| `Views/Map/MapView.swift` | SwiftUI View | 顶层容器，组装 SearchBar / MapKitView / 底部卡片 / 添加按钮，承接 `selectedEntries`、`query` 状态，注入 ViewModel |
| `Views/Map/MapKitView.swift` | `UIViewRepresentable` | 包 `MKMapView`：注解管理、聚合配置、tap 回调、`region` 暴露给 ViewModel |
| `Views/Map/EntryAnnotation.swift` | `NSObject, MKAnnotation` | 持有 `Entry.objectID`、`coordinate`、`title`；`clusteringIdentifier = "entry"` |
| `Views/Map/MapSearchBar.swift` | SwiftUI View | 胶囊形搜索框，暖色描边，`@Binding var query: String` |
| `Views/Map/MapEntryCard.swift` | SwiftUI View | 底部上浮卡片：横滑列表，每张卡片展示日期/地点/摘要/缩略图，点击进 `EntryDetailView` |
| `ViewModels/MapViewModel.swift` | `@MainActor ObservableObject` | `@Published entries`, `@Published query`, `var visibleEntries`, `func reload()` |

## 4. 界面布局

```
┌─────────────────────────────────────┐ ← MainTabView 顶部条（沿用 gearshape）
│  ⚙︎                                │
├─────────────────────────────────────┤ ← MapView 自身顶部
│  ┌──────────────────────────────┐  │
│  │ 🔍  搜索地点或日记内容        │  │  ← MapSearchBar
│  └──────────────────────────────┘  │
│                                     │
│             MKMapView               │
│        （pin + 聚合气泡）            │
│                                     │
│                            ┌──┐    │
│                            │ ＋ │    │  ← 右下浮动添加按钮
│                            └──┘    │
│  ┌──────────────────────────────┐  │
│  │  📅 6月20日 · 上海·七宝       │  │  ← MapEntryCard（仅在 pin 被选中时显示）
│  │  早晨在交大走了一圈...        │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

- 搜索框与 MapView 顶部之间留 12pt（参考 UI 中搜索框与底部分段栏的间距）。
- 添加按钮：直径 56，背景 `Color(hex: "1C1C24")`，白色 `plus`，距底/距右各 24，距底部卡片（若可见）16。
- 底部卡片：当 `selectedEntries.isEmpty == false` 时上浮；高度 ~140，圆角 20，`.warmLight` 背景；点击卡片外区域 / 拖拽下滑收起。

## 5. 聚合策略

- `MapKitView.makeUIView` 注册 `MKMarkerAnnotationView`，在 `mapView(_:viewFor:)` 为 `EntryAnnotation` 返回带 `clusteringIdentifier = "entry"` 的 view，颜色 `Color.warmAccent`。
- 聚合气泡走系统默认 `MKMarkerAnnotationView` for `MKClusterAnnotation`，配深灰背景 + 白字 count，与参考图一致。
- 点击单 pin：回调 `[entry]`；点击聚合气泡：取 `cluster.memberAnnotations as? [EntryAnnotation]` 还原 `[Entry]`，回调多条。

## 6. 搜索行为

- `query` 变更 → ViewModel 重算 `visibleEntries`。
- 命中首条时不自动移动地图（避免抢用户视角）；保留地图原位置，由聚合气泡天然引导用户。
- 清空搜索：恢复全部 pin。
- 匹配规则：忽略大小写 + 变音；任一字段（`title`, `content`, `location.placeName`）包含即命中。

## 7. 选中状态与底部卡片

- `selectedEntries: [Entry]` 由 `MapView` 持有；`MapKitView` 通过 closure 回写。
- 点击地图空白处 → 清空 `selectedEntries`。
- 同坐标多条：底部卡片横滑（`TabView(.page)` 或 `ScrollView(.horizontal)`），右下角小指示器表示条数。
- 单条：单张卡片占满宽度。
- 卡片样式：左上日期（`yyyy.MM.dd`），右上小天气图标，主体一行 placeName + 截断的 content；可点。

## 8. 添加按钮

- 由 `MapView` 的 `@Binding var showingNewEntry: Bool`（来自 `MainTabView`）控制；点击置 `true`，复用 MainTabView 已有的 `.sheet(showingNewEntry) { EntryEditorView(...) }`。
- `EntryEditorViewModel.fetchLocationAndWeather` 已自动抓定位，不需要 MapView 显式传位置。

## 9. 空态

- `entries.isEmpty == true`：地图正常显示（聚焦用户当前位置），中央叠加一个半透明卡片：
  - 文案："还没有带位置的日记"
  - 副文案："点击 ＋ 添加第一条"
  - 视觉：`Color.warmLight.opacity(0.95)` 圆角卡片 + `mappin.slash` 图标。
- `entries` 不空但 `visibleEntries.isEmpty`（搜索无结果）：底部 toast 风格提示「无匹配结果」。

## 10. 与 MainTabView 的整合

- `MainTabView.swift` 中 `if selectedTab == .map { PlaceholderView(...) }` 替换为：
  ```swift
  if selectedTab == .map {
      MapView(showingNewEntry: $showingNewEntry)
          .transition(.paperDrop)
  }
  ```
- 现有的右上角 list/grid 按钮守卫 `if selectedTab == .list` 已经天然排除 map，无需修改。
- `MapView` 内部用 `safeAreaInset(edge: .top)` 顶部留出抽屉按钮位置（约 60pt）。

## 11. 错误处理

- 定位权限拒绝：地图正常工作，仅不聚焦用户当前位置（默认聚焦到所有 pin 的 bounding region；若无 pin，落到一个固定 fallback 坐标，例如上海 31.23, 121.47）。
- Core Data fetch 失败：`MapViewModel` 内部 try? 静默；`entries` 为空走空态。
- 不需要专门的错误 UI。

## 12. 测试范围

- 手动验证（无单测）：
  1. 抽屉切到「地图」→ 显示 MapView，无崩溃。
  2. 创建几条带位置的日记 → 地图上出现 pin。
  3. 缩小地图 → 多个 pin 自动聚合为带数字的气泡。
  4. 点击 pin → 底部卡片弹出；点击卡片 → 进入 EntryDetailView。
  5. 搜索框输入 placeName 关键字 → pin 数量减少；清空 → 恢复。
  6. 右下「＋」→ 弹出 EntryEditorView，保存后地图上多一个 pin。
  7. 空态：清空所有日记 → 中央空态提示出现。
- 构建验证：`xcodebuild build` 必须 BUILD SUCCEEDED。
