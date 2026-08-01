# 阶段 E · On This Day 周年回顾 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) 或 superpowers:executing-plans task-by-task。本计划以 subagent-driven 模式写就——每个 task 一个 implementer subagent + spec/quality 双审 + 阶段 E 整分支宽审。Checkbox 用 `- [ ]`。

**Goal:** 在 TimelineView 列表模式顶部插入「On This Day 周年回顾」区块,展示历史上同月同日写过的日记,严格同月同日匹配,顶部汇总条 + 每年一行(倒序),点行跳 EntryDetailView。

**Architecture:** 新建 `OnThisDayViewModel`(`@MainActor ObservableObject`,持有 `groups`/`totalCount`/`recentYearDiff` 计算逻辑)+ `OnThisDaySection.swift`(汇总条 + 年行 ForEach + 空态隐藏)+ `OnThisDayYearRow.swift`(单年行 + NavigationLink)。改动 `TimelineListView.swift` 顶端插入 `OnThisDaySection()`。**零 schema 改动,零新依赖**。

**Tech Stack:** SwiftUI + Core Data `NSFetchRequest` + Foundation `Calendar` + MVVM,沿用项目暖色 token 与 `.warmCard()` modifier。

## 全局约束(全阶段 E 不变)

- **commit message** 中文 Conventional Commits(`类型: 描述`);E1 一个 commit。
- **构建命令**(从 `/Users/rich1e/workspace/code/dayfold/dayfold` 子目录跑,项目在该子目录):
  ```
  xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
  ```
  必须 `** BUILD SUCCEEDED **`。SourceKit 在 CLI 下对跨文件类型会误报,一律忽略,以 xcodebuild 为准。
- **暖色 token**:严格使用 `Color.warmPaper / warmCream / warmLight / warmBrown / warmAccent / warmGray / warmDark`(定义见 `Extensions/Color+Warm.swift`)。**不引入新颜色**。
- **字体 token**:`Font.warmTitle / warmHeadline / warmBody / warmCaption / warmFootnote`。
- **导航容器**:本仓库全部用 `NavigationView`,不升级 NavigationStack。
- **不引入新依赖**:仅 Foundation `Calendar` + Core Data `NSFetchRequest`,不引入 PDFKit / AVFoundation 等。
- **不改动 schema**:`dayfold.xcdatamodeld/` 零修改。
- **环境对象**:`dayfoldApp` 已注 `securityManager` + `coreDataStack` + `\.managedObjectContext`,新代码沿用。
- **all sheet / fullScreenCover 内** `.environment(\.managedObjectContext, viewContext)`(本阶段无新增 sheet)。
- **不自动 push**:`git push` 需用户明确指令,详见 `~/.claude/projects/.../memory/feedback_no-auto-push.md`。
- **本阶段 E 仅 1 个 task(E1)**,因为 MVP 范围小(3 文件:ViewModel + Section + YearRow),不值得拆 2 个。但 implementer 仍按「先 ViewModel 编译通过 → 再接 Section 渲染 → 最后 YearRow 跳详情」3 个 bite-sized step 内部推进。

---

## Task E1:OnThisDay 区块全链路

**Files:**
- Create: `dayfold/dayfold/ViewModels/OnThisDayViewModel.swift`
- Create: `dayfold/dayfold/Views/Timeline/OnThisDaySection.swift`
- Create: `dayfold/dayfold/Views/Timeline/OnThisDayYearRow.swift`
- Modify: `dayfold/dayfold/Views/Timeline/TimelineListView.swift`(LazyVStack 顶端插入 OnThisDaySection)

**Interfaces:**
- Consumes: `Entry.createdAt / deletedAt / wrappedTitle / wrappedContent`、`Calendar.current`、`Color.warmPaper / warmCream / warmLight / warmBrown / warmAccent / warmGray / warmDark`、`.warmCard()`、`Font.warmHeadline / warmCaption / warmBody / warmFootnote`。
- Produces: TimelineView 列表模式顶部出现「On This Day」区块;空态隐藏;点行跳 EntryDetailView。

### Step 1:新建 OnThisDayViewModel(含 @Published 三字段 + OnThisDayYearGroup 结构 + refresh 算法)

文件:`dayfold/dayfold/ViewModels/OnThisDayViewModel.swift`

```swift
import Foundation
import CoreData

@MainActor
final class OnThisDayViewModel: ObservableObject {
    @Published private(set) var groups: [OnThisDayYearGroup] = []  // 倒序,yearDiff 从大到小
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var recentYearDiff: Int = 0  // 最近一年是 K 年前;0 = 无历史

    struct OnThisDayYearGroup: Identifiable {
        let id: ObjectIdentifier
        let yearDiff: Int
        let earliest: Entry
        let count: Int
    }

    private let context: NSManagedObjectContext
    private let calendar: Calendar

    init(context: NSManagedObjectContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func refresh() {
        let now = Date()
        let nowYear = calendar.dateComponents([.year], from: now).year ?? 0
        let nowMonth = calendar.dateComponents([.month], from: now).month ?? 0
        let nowDay = calendar.dateComponents([.day], from: now).day ?? 0

        let req = NSFetchRequest<Entry>(entityName: "Entry")
        req.predicate = NSPredicate(format: "deletedAt == nil")
        let all = (try? context.fetch(req)) ?? []

        let matching = all.filter { e -> Bool in
            guard let created = e.createdAt else { return false }
            if calendar.isDateInToday(created) { return false }
            let comps = calendar.dateComponents([.year, .month, .day], from: created)
            return comps.month == nowMonth && comps.day == nowDay && comps.year != nowYear
        }

        let byYear = Dictionary(grouping: matching) { e -> Int in
            calendar.dateComponents([.year], from: e.createdAt ?? Date()).year ?? 0
        }

        let mapped = byYear.compactMap { (year, entries) -> OnThisDayYearGroup? in
            let diff = nowYear - year
            guard diff >= 1 else { return nil }
            let sorted = entries.sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
            guard let earliest = sorted.first else { return nil }
            return OnThisDayYearGroup(
                id: ObjectIdentifier(earliest),
                yearDiff: diff,
                earliest: earliest,
                count: entries.count
            )
        }
        .sorted { $0.yearDiff > $1.yearDiff }

        groups = mapped
        totalCount = matching.count
        recentYearDiff = mapped.last?.yearDiff ?? 0
    }
}
```

> 注意:`comps.year != nowYear` 同时排除「今天」(已被 `isDateInToday` 排除)+「同年其它天」(不应进入)。

### Step 2:新建 OnThisDaySection.swift(汇总条 + ForEach 年行 + 空态隐藏)

文件:`dayfold/dayfold/Views/Timeline/OnThisDaySection.swift`

```swift
import SwiftUI

struct OnThisDaySection: View {
    @StateObject private var viewModel: OnThisDayViewModel

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: OnThisDayViewModel(context: context))
    }

    var body: some View {
        if !viewModel.groups.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                summaryCard
                ForEach(viewModel.groups) { group in
                    OnThisDayYearRow(group: group)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .task { viewModel.refresh() }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.warmAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("历史上今天你写了 \(viewModel.totalCount) 篇日记")
                    .font(.warmHeadline)
                    .foregroundColor(.warmDark)
                Text("最近一篇是 \(viewModel.recentYearDiff) 年前的今天")
                    .font(.warmCaption)
                    .foregroundColor(.warmBrown)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .warmCard()
    }
}
```

### Step 3:新建 OnThisDayYearRow.swift(单年行 + NavigationLink 跳详情)

文件:`dayfold/dayfold/Views/Timeline/OnThisDayYearRow.swift`

```swift
import SwiftUI

struct OnThisDayYearRow: View {
    let group: OnThisDayViewModel.OnThisDayYearGroup

    var body: some View {
        NavigationLink(destination: EntryDetailView(entry: group.earliest)) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("\(group.yearDiff) 年前")
                        .font(.warmCaption)
                        .foregroundColor(.warmBrown)
                    Circle()
                        .fill(Color.warmAccent)
                        .frame(width: 8, height: 8)
                }
                .frame(width: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.warmBody)
                        .foregroundColor(.warmDark)
                        .lineLimit(1)
                    Text(group.earliest.wrappedContent)
                        .font(.warmCaption)
                        .foregroundColor(.warmBrown)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if group.count > 1 {
                    Text("+\(group.count) 篇同天")
                        .font(.warmFootnote)
                        .foregroundColor(.warmGray)
                }
            }
            .padding(16)
            .warmCard()
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var displayTitle: String {
        let t = group.earliest.wrappedTitle
        return t.isEmpty ? "无标题" : t
    }
}
```

### Step 4:TimelineListView 顶端插入 OnThisDaySection

文件:`dayfold/dayfold/Views/Timeline/TimelineListView.swift`

找到 `body` 内 `LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {` 之后,在 `ForEach(groupedEntries...)` 之前插入 `OnThisDaySection(context: ?)`。

**关键问题**:`TimelineListView` 当前没有 `@Environment(\.managedObjectContext)` 也没有 init 参数。需要二选一:

**方案 A(推荐,改动小)**:在 `TimelineListView` 加 `@Environment(\.managedObjectContext) private var viewContext`,然后 `OnThisDaySection(context: viewContext)`。`@Environment` 在 `NavigationView` 内自动可用。

**方案 B**:改 `TimelineListView` 为 `TimelineListView(context: NSManagedObjectContext)` 显式传 context(需同步改 `TimelineView` 调用方 `TimelineListView()` → `TimelineListView(context: viewContext)`)。

实施选 **方案 A**(影响面更小,符合 `dayfoldApp` 已注 context 的现状)。

具体 diff(在 `TimelineListView.swift`):

```swift
struct TimelineListView: View {
    @Environment(\.managedObjectContext) private var viewContext   // 新增

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)],
        animation: .default
    )
    private var entries: FetchedResults<Entry>
    // ... 其余不变

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                OnThisDaySection(context: viewContext)   // 新增
                ForEach(groupedEntries, id: \.0) { date, dayEntries in
                    // ... 既有
                }
            }
        }
        // ... 既有
    }
}
```

### Step 5:构建 + 提交

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild ... build 2>&1 | tail -5
```
期望 `** BUILD SUCCEEDED **`。SourceKit 误报忽略。

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/ViewModels/OnThisDayViewModel.swift \
        dayfold/dayfold/Views/Timeline/OnThisDaySection.swift \
        dayfold/dayfold/Views/Timeline/OnThisDayYearRow.swift \
        dayfold/dayfold/Views/Timeline/TimelineListView.swift
git commit -m "feat(timeline): On This Day 周年回顾区块"
```

### 验收点

| # | 项 | 核对路径 |
|---|-----|------|
| E1.1 | TimelineView 列表模式顶部出现「On This Day」区块 | TimelineListView 顶端 OnThisDaySection |
| E1.2 | 严格同月同日匹配,排除今天 + 排除同年 | OnThisDayViewModel.refresh `comps.month == && comps.day == && comps.year != nowYear` + `isDateInToday` |
| E1.3 | 倒序:K 年前 → 1 年前 | OnThisDayYearGroup 数组 `.sorted { $0.yearDiff > $1.yearDiff }` |
| E1.4 | 顶部汇总条 + 每年一行 双层结构 | OnThisDaySection.summaryCard + ForEach groups |
| E1.5 | 点行跳 EntryDetailView | OnThisDayYearRow 外层包 `NavigationLink(destination: EntryDetailView(entry:))` |
| E1.6 | 空态不渲染整区块 | `if !viewModel.groups.isEmpty { ... }` 包裹整个 body |
| E1.7 | 无新依赖 | grep 无 PDFKit/AVFoundation |
| E1.8 | 无 schema 改动 | `git diff` 不动 `dayfold.xcdatamodeld/` |
| E1.9 | 暖色 token 严格 | `.warmCard()` + warmPaper / warmAccent / warmBrown / warmDark / warmGray + warmHeadline/Caption/Body/Footnote |
| E1.10 | xcodebuild BUILD SUCCEEDED | `cd dayfold && xcodebuild ... build 2>&1 \| tail -5` |

---

## Verification(阶段 E 完工后核对)

1. **构建**:`xcodebuild ... build` `** BUILD SUCCEEDED **`
2. **数据准备**:模拟器新建几篇日记,手动把其中 1-2 篇的 `createdAt` 改成去年/前年/3 年前的今天(用 SQLite 工具或临时 debug 入口),然后打开 App → Timeline → 看到顶部「N 年前的今天」卡片
3. **空态**:清空所有日记后,TimelineView 顶部区块消失(不留占位)
4. **跳详情**:点区块某一行,跳 EntryDetailView 显示该年同天最早一篇
5. **回归**:阶段 A/B/C/D 的所有功能仍正常工作(笔记本、编辑器、TagPicker、mood、saveError、TagsView、EntryListView 筛选、PhotoWall 点击、StatsView、SettingsView)
6. **schema 验证**:`git diff origin/main -- dayfold/dayfold.xcdatamodeld/` 应为空(零 schema 改动)
7. **阶段 E 整体目标**:设计文档「情感锚点打通」验收 — TimelineView 顶部出现回顾卡,空态隐藏,跳详情 OK