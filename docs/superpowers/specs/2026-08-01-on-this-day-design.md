# 阶段 E · On This Day 周年回顾 设计文档

> 生成日期:2026-08-01
> 背景:阶段 0 + A + B + C + D 全部完成,main HEAD `b39c4c9`,领先 origin/main 31 commits(未推)。本轮在 5 份已有 spec 与 `PROJECT_OVERVIEW.md` 中,挑出唯一被 `2026-04-07-...-design.md §2.2 v1.2` 白纸黑字点名 + 零架构风险的『On This Day 历史回顾』做 MVP。
> 依据:`dayfold/dayfold/` 源码实测(`Entry.createdAt` 是 `Date?`、软删判 `deletedAt != nil`、TimelineListView 已有 `NavigationLink` 跳 `EntryDetailView`)。

## 一、目标与范围

让用户打开 TimelineView 列表模式时,顶部看到「N 年前的今天」回顾卡,把日记 App 的情感锚点打通。MVP 范围内最小可用闭环,不做暗黑验证、不做空态动效、不接地图/统计页、不重做 TimelineView 容器。

| # | 缺口 | 现状 | 阶段 |
|---|------|------|------|
| 1 | TimelineView 列表顶部无周年回顾入口 | TimelineListView 直接进日期分组列表,用户无情感锚点 | E1 |
| 2 | 无「同月同日」年份差计算 | 无独立 VM,数据靠 `Entry.createdAt` 但未聚合 | E2 |

## 二、关键决策(已与用户确认)

1. **展示位置:TimelineView 顶部(列表模式内)** —— 插入 `TimelineListView` 的 `LazyVStack` 顶端,日历/照片墙模式不显示(避免视觉干扰)。
2. **检索语义:严格同月同日匹配** —— 不做 ±1 天/±7 天容差。`Calendar.dateComponents([.month, .day], from:)` 比对。
3. **结构:顶部汇总条 + 每年一行** —— 汇总条说『历史上今天写了 N 篇,最早是 K 年前』;每年一行倒序,只展示存在日记的年份。
4. **交互:点行跳 EntryDetailView** —— 该年同天多篇时跳最早一篇(避免简单排序乱序)。
5. **MVP 范围,不做**:
   - 深色模式专项适配(暖色 token 已 work in dark,本轮不压测)
   - 空态动效(无历史日记时不显示该区块即可)
   - 跨 Tab 复用(只在 TimelineView 出现)
   - 暗黑/横屏/小屏适配(沿用现有 `.warmCard()` modifier)
6. **零 schema 改动** —— 仅读 `Entry.createdAt` / `deletedAt` / `wrappedTitle` / `wrappedContent`,不新增字段、不动 `.xcdatamodeld`。
7. **零新依赖** —— 仅用 Foundation `Calendar` + Core Data `NSFetchRequest`,不引入 PDFKit / AVFoundation 等。

## 三、架构与数据流

```
TimelineView (列表模式)
└── TimelineListView (LazyVStack 顶端)
    └── OnThisDaySection (新增,@StateObject ViewModel)
        ├── OnThisDaySummary (顶部汇总条:count + earliestYearDiff)
        └── OnThisDayYearRow × N (每年一行,倒序,点跳 EntryDetailView)

OnThisDayViewModel(context)
├── fetchMatchingEntries() → [Entry] (predicate: deletedAt == nil AND createdAt 的 .month/.day == today)
├── groupByYear() → [(yearDiff: Int, earliest: Entry, count: Int)]
└── summary → (count: Int, earliestYearDiff: Int)
```

**新增文件**(全部新建,不动其它代码):
- `dayfold/dayfold/Views/Timeline/OnThisDaySection.swift` —— 区块 View(汇总条 + 年行 + 空态隐藏)
- `dayfold/dayfold/ViewModels/OnThisDayViewModel.swift` —— `OnThisDayYearGroup` 结构 + 计算逻辑
- `dayfold/dayfold/Views/Timeline/OnThisDayYearRow.swift` —— 单年行卡片

**修改文件**:
- `dayfold/dayfold/Views/Timeline/TimelineListView.swift` —— `LazyVStack` 顶端插入 `OnThisDaySection`(只在 `groupedEntries` 非空或历史非空时显示)

## 四、核心算法

### 4.1 取同月同日历史 Entry

```swift
@MainActor
final class OnThisDayViewModel: ObservableObject {
    @Published private(set) var groups: [OnThisDayYearGroup] = []  // 倒序,yearDiff 从大到小
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var recentYearDiff: Int = 0  // 最近一年是 K 年前;0 = 无历史

    struct OnThisDayYearGroup: Identifiable {
        let id: ObjectIdentifier  // earliest.objectID
        let yearDiff: Int         // 距离今天多少整年
        let earliest: Entry       // 该年同天最早一篇
        let count: Int            // 该年同天总篇数
    }

    private let context: NSManagedObjectContext
    init(context: NSManagedObjectContext) { self.context = context }

    func refresh() {
        let now = Date()
        let cal = Calendar.current
        let nowMonthDay = cal.dateComponents([.month, .day], from: now)

        // 拉所有非软删
        let req = NSFetchRequest<Entry>(entityName: "Entry")
        req.predicate = NSPredicate(format: "deletedAt == nil")
        let all = (try? context.fetch(req)) ?? []

        // 过滤同月同日(排除今天本身,排除未来日记)
        let matching = all.filter { e -> Bool in
            guard let created = e.createdAt else { return false }
            let cmp = cal.dateComponents([.month, .day], from: created)
            return cmp.month == nowMonthDay.month && cmp.day == nowMonthDay.day
                && !cal.isDateInToday(created)
        }

        // 按年分组
        let byYear = Dictionary(grouping: matching) { e -> Int in
            cal.dateComponents([.year], from: e.createdAt ?? Date()).year ?? 0
        }
        let nowYear = cal.dateComponents([.year], from: now).year ?? 0

        let mapped = byYear.compactMap { (year, entries) -> OnThisDayYearGroup? in
            let diff = nowYear - year
            guard diff >= 1 else { return nil }  // 排除同一年残留
            let sorted = entries.sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
            guard let earliest = sorted.first else { return nil }
            return OnThisDayYearGroup(id: ObjectIdentifier(earliest), yearDiff: diff,
                                      earliest: earliest, count: entries.count)
        }
        .sorted { $0.yearDiff > $1.yearDiff }  // 倒序:3 年前 → 2 年前 → 1 年前

        groups = mapped
        totalCount = matching.count
        recentYearDiff = mapped.last?.yearDiff ?? 0  // 最近的是 1 年前;0 表示无历史
    }
}
```

### 4.2 空态与节流

- `groups.isEmpty` → View 不渲染该区块(整块隐藏,不留占位)
- `refresh()` 在 `OnThisDaySection` `.task` 触发一次即可,无定时器
- 现有 TimelineListView `.task` 已有 `entries.count` 监听自动刷新 → 写一篇同天日记 → 下次进入 Timeline 自动重新计算

### 4.3 跨年边缘

- 元旦当天(今天 1/1):2018/1/1 entry 与 2020/1/1 entry 都严格匹配 `.month==1 && .day==1`,都正确进 groups
- 用户跨时区写日记:`Calendar.current` 自动跟随设备时区,旅行日记按写日记当时时区算月日,后续跨时区打开 Timeline 会按当前时区重算 → 与现有「定位/天气」逻辑一致,不破坏用户预期
- 夏令时/秒级跳变:无影响,只看月日不看时分

## 五、UI 与交互规范

### 5.1 OnThisDaySummary(顶部汇总)

- 全宽 `.warmCard()` 容器,水平排版
- 左侧:小 SF Symbol `clock.arrow.circlepath`(暖色 warmAccent,16pt)
- 中部:VStack
  - 主标题:`『历史上今天你写了 N 篇日记』`(N 用阿拉伯数字,Locale 自然渲染),Font `.warmHeadline`,warmDark
  - 副标题:`『最早是 K 年前的今天』`(K = `recentYearDiff`,最近一年是 K 年前;K=0 时整块隐藏),Font `.warmCaption`,warmBrown
- 右侧:无(N≥1 显示该条;N=0 不渲染整区块)
- 上下 padding 16,左右 padding 16

### 5.2 OnThisDayYearRow(每年一行)

- 全宽 `.warmCard()` 容器
- 左:VStack 居中
  - 上:`K 年前`(K = yearDiff),Font `.warmCaption`,warmBrown
  - 下:小 Circle warmAccent 直径 8(与 TimelineEntryCard 时间标记呼应)
- 中:VStack 左对齐
  - 上:`earliest.wrappedTitle`(空时显示无标题预览),Font `.warmBody`,warmDark
  - 下:`earliest.wrappedContent` 1 行省略,Font `.warmCaption`,warmBrown
  - 最右标签角:`+ M 篇同天`(M = count,>1 才显示),Font `.warmFootnote`,warmGray
- 整行包裹 `NavigationLink(destination: EntryDetailView(entry: group.earliest))`,沿用 TimelineListView 既有 `NavigationLink` 跳法

### 5.3 区块入口位置

```swift
// TimelineListView.body 内 LazyVStack 顶端
LazyVStack(...) {
    OnThisDaySection()                  // 新增,自动隐藏空态
        .padding(.horizontal)
        .padding(.top, 8)
    ForEach(groupedEntries, id: \.0) { ... }  // 既有日期分组
}
```

不破坏既有 `.animation(.easeOut...)` 节流与 `.transition(.paperDrop)` 切换。

## 六、验收标准

| # | 项 | 核对路径 |
|---|-----|------|
| E1.1 | TimelineView 列表模式顶部出现「On This Day」区块 | TimelineListView 顶端 OnThisDaySection |
| E1.2 | 严格同月同日匹配,排除今天 | OnThisDayViewModel.refresh 算法 |
| E1.3 | 倒序:K 年前 → 1 年前 | OnThisDayYearGroup.sorted by yearDiff desc |
| E1.4 | 汇总条 + 每年一行 双层结构 | OnThisDaySection 拆 OnThisDaySummary + ForEach groups |
| E1.5 | 点行跳 EntryDetailView | OnThisDayYearRow 包 NavigationLink |
| E1.6 | 空态不渲染整区块 | groups.isEmpty → View 整体 hidden |
| E1.7 | 无新依赖 | grep 无 PDFKit/AVFoundation 等 |
| E1.8 | 无 schema 改动 | git diff 不动 `dayfold.xcdatamodeld/` |
| E1.9 | 暖色 token 严格 | Color.warmPaper / warmAccent / warmBrown / warmDark + .warmCard() |
| E1.10 | xcodebuild BUILD SUCCEEDED | `cd dayfold && xcodebuild ... build 2>&1 \| tail -5` |

## 七、不做(明确延后)

1. 深色模式专项压测(暖色 token 在 dark 已可用,本轮不验证)
2. 空态「无历史日记」引导文案(空态直接隐藏即可,无 user-facing 干扰)
3. 日历模式/照片墙模式插入(避免视觉干扰)
4. 跨 Tab 复用(HomeView 顶部 / EntryListView 顶部)
5. 翻页动效 / 3D 翻转(沿用现有 `.transition(.paperDrop)`)
6. 视频/位置/天气维度的「今天也去了这里」(地图页已有,不在 TimelineView 重复)

## 八、风险

- **零架构风险**:不动 schema、不动 Service、不动 Navigator 容器
- **唯一浮点**:跨年日记(元旦前后写)按用户写日记当时时区算月日,后续跨时区打开 Timeline 重算 → 与项目一致(定位/天气同逻辑)
- **性能**:1 次 NSFetchRequest 拉全部非软删 entry(MVP 数据量 100 篇内不需优化;若后续 >1000 篇再考虑 predicate 精确化)