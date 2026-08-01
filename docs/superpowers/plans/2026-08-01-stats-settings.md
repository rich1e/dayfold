# 阶段 D · 统计/设置页 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) 或 superpowers:executing-plans task-by-task。本计划以 subagent-driven 模式写就——每个 task 一个 implementer subagent + spec/quality 双审 + 阶段 D 整分支宽审。Checkbox 用 `- [ ]`。

**Goal:** 让 Dayfold 在抽屉「数据统计」与「设置」入口下展示真实数据,而不是占位页。统计页给出连续记录天数、总数、标签分布等核心维度;设置页提供 Face ID 持久化、默认笔记本选择、iCloud 同步状态、版本号。

**Architecture:** 新建 StatsView + StatsViewModel(读 CoreData 聚合);新建 SettingsView(本地状态 + UserDefaults + 复用已有 SecurityManager/CoreDataStack/NotebookPickerSheet);SecurityManager 加 UserDefaults 持久化;MainTabView 替换两处 PlaceholderView 分支。**只新建 2 个 View + 1 个 VM 文件,改 SecurityManager 1 处 + MainTabView 2 处。**

**Tech Stack:** SwiftUI + Core Data + MVVM + UserDefaults(本项目首次引入,用于设置持久化)

## 全局约束(全阶段不变)

- **commit message** 中文 Conventional Commits(`类型: 描述`);D1 / D2 各一个 commit,顺序按 D1→D2。
- **构建命令**(从 `/Users/rich1e/workspace/code/dayfold/dayfold` 子目录跑,项目在该子目录):
  ```
  xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
  ```
  必须 `** BUILD SUCCEEDED **`。SourceKit 在 CLI 下对跨文件类型会误报,一律忽略,以 xcodebuild 为准。
- **暖色 token**:严格使用 `Color.warmPaper / warmCream / warmLight / warmBrown / warmAccent / warmGray / warmDark`(定义见 `Extensions/Color+Warm.swift`)。**不引入新颜色**(iCloud 状态圆点用 `warmAccent` / `warmGray`)。
- **导航容器**:本仓库全部用 `NavigationView`,不升级 NavigationStack。
- **不引入新依赖**;只新增 2 个 View + 1 个 VM 文件。
- **设计稿**:stats / settings 没有 Stitch 设计稿,展现形式按 spec 文字描述 + 暖色主题自由实现;**布局对齐项目主流风格(ScrollView + VStack 多 warmCard)**。
- **环境对象**:`SecurityManager` 与 `CoreDataStack` 已在 `dayfoldApp.swift` 根层注入,MainTabView 的 `.settings` 分支直接渲染 `SettingsView()` 自动继承,无需额外注入。
- **所有 sheet / fullScreenCover 内** `.environment(\.managedObjectContext, viewContext)`(D2 的 `NotebookPickerSheet` 自带 context 注入,无需额外加)。

---

## Task D1:StatsView 数据统计页

**Files:**
- Create: `dayfold/dayfold/Views/StatsView.swift`
- Create: `dayfold/dayfold/ViewModels/StatsViewModel.swift`
- Modify: `dayfold/dayfold/Views/MainTabView.swift`(`.stats` 分支 PlaceholderView → StatsView)

**Interfaces:**
- Consumes: `Entry.createdAt / mediaAssetsArray / location / tagsArray / isInTrash`、`Tag.entriesArray`、`Calendar.current`、`Color.warmLight / warmBrown / warmAccent / warmDark / warmPaper`、`.warmCard()`、`Font.warmTitle / warmHeadline / warmCaption / warmFootnote`。
- Produces: 抽屉「数据统计」入口落地,展示 6 个统计维度(总日记数 / 本月 / 今年 / 连续天数 / 标签分布 / 带图比例 / 带位置比例)。

### Step 1:新建 StatsViewModel

创建 `dayfold/dayfold/ViewModels/StatsViewModel.swift`:

```swift
@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var totalEntries = 0
    @Published private(set) var monthEntries = 0
    @Published private(set) var yearEntries = 0
    @Published private(set) var currentStreak = 0
    @Published private(set) var tagDistribution: [(Tag, Int)] = []
    @Published private(set) var mediaRatio: Double = 0
    @Published private(set) var locationRatio: Double = 0

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func refresh() {
        let req = NSFetchRequest<Entry>(entityName: "Entry")
        req.predicate = NSPredicate(format: "deletedAt == nil")
        let entries = (try? context.fetch(req)) ?? []
        let cal = Calendar.current
        let now = Date()

        totalEntries = entries.count
        monthEntries = entries.filter { cal.isDate($0.createdAt ?? Date(), equalTo: now, toGranularity: .month) }.count
        yearEntries  = entries.filter { cal.isDate($0.createdAt ?? Date(), equalTo: now, toGranularity: .year) }.count

        // streak:从今天反向遍历,连续日
        var days = Set<Date>()
        for e in entries {
            if let d = e.createdAt { days.insert(cal.startOfDay(for: d)) }
        }
        var streak = 0
        var day = cal.startOfDay(for: now)
        while days.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        currentStreak = streak

        let withMedia = entries.filter { !$0.mediaAssetsArray.isEmpty }.count
        let withLoc   = entries.filter { $0.location != nil }.count
        mediaRatio    = totalEntries == 0 ? 0 : Double(withMedia) / Double(totalEntries)
        locationRatio = totalEntries == 0 ? 0 : Double(withLoc)   / Double(totalEntries)

        // 标签分布:遍历所有 tag,统计非软删 entry 数
        let tagReq = NSFetchRequest<Tag>(entityName: "Tag")
        let tags = (try? context.fetch(tagReq)) ?? []
        tagDistribution = tags
            .map { ($0, $0.entriesArray.filter { !$0.isInTrash }.count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }
}
```

注意:`Entry.createdAt` 在 Swift 类型上是 `Date?`(CoreData 可选),所有用 `?? Date()` 兜底。`tagDistribution: [(Tag, Int)]` 元组数组不可 diff,若 SwiftUI 列表渲染不响应,改为 `[(tag: Tag, count: Int)]` named tuple + `@Published var tagDistribution: [TagStat] = []` 配 `struct TagStat { let tag: Tag; let count: Int }` —— **请先尝试元组,若不响应则升级 struct。**

### Step 2:新建 StatsView

创建 `dayfold/dayfold/Views/StatsView.swift`:

```swift
struct StatsView: View {
    @StateObject private var viewModel: StatsViewModel

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(context: context))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard           // 三个数字横排:总数 / 本月 / 今年
                streakCard           // 大字 streak
                ratioCard            // 带图% / 带位置%
                tagDistributionCard  // 标签 Top N
            }
            .padding()
        }
        .background(Color.warmPaper.ignoresSafeArea())
        .onAppear { viewModel.refresh() }
    }

    // 子视图定义略,均用 .warmCard() + Font.warmTitle + Font.warmCaption
}
```

### Step 3:MainTabView 替换 .stats 分支

打开 `MainTabView.swift`:

- 定位 `.stats` 分支的 `PlaceholderView(...)`(L61-64 附近),替换为:
  ```swift
  if selectedTab == .stats {
      StatsView(context: viewContext)
          .transition(.paperDrop)
  }
  ```

### Step 4:构建 + 提交

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild ... build 2>&1 | tail -5
```
期望 `** BUILD SUCCEEDED **`。SourceKit 误报忽略。

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/Views/StatsView.swift \
        dayfold/dayfold/ViewModels/StatsViewModel.swift \
        dayfold/dayfold/Views/MainTabView.swift
git commit -m "feat(stats): 实现统计页 (StatsView + StatsViewModel)"
```

### 验收点

| # | 项 | 核对路径 |
|---|-----|------|
| D1.1 | 「数据统计」不再是占位文案 | MainTabView `.stats` 分支替换为 `StatsView(context: viewContext)` |
| D1.2 | 6 个维度全部展示 | StatsView 的 headerCard / streakCard / ratioCard / tagDistributionCard |
| D1.3 | streak 算法正确 | 从 `Calendar.startOfDay(for: now)` 反向遍历 Set,遇缺即停 |
| D1.4 | 软删不计入 | 全部 fetch predicate `deletedAt == nil`;tagDistribution 二次过滤 `!isInTrash` |
| D1.5 | 空数据不闪退 | 全 0 / streak=0 / 比例=0 安全 |
| D1.6 | 暖色 token 严格 | `.warmCard()` / `Color.warmPaper / warmBrown / warmAccent` / `Font.warmTitle / warmCaption` |

---

## Task D2:SettingsView 设置页

**Files:**
- Create: `dayfold/dayfold/Views/SettingsView.swift`
- Modify: `dayfold/dayfold/Services/SecurityManager.swift`(加 init + setEnabled 持久化)
- Modify: `dayfold/dayfold/Views/MainTabView.swift`(`.settings` 分支 PlaceholderView → SettingsView)

**Interfaces:**
- Consumes: `SecurityManager.isEnabled`(改造后含持久化)、`CoreDataStack.isCloudKitAvailable`、`NotebookPickerSheet(title:onSelect:)`(已存在的 `Views/Common/NotebookPickerSheet.swift`)、`Bundle.main.infoDictionary["CFBundleDisplayName"]`、`.warmCard()`、暖色 token。
- Produces: 抽屉「设置」入口落地;Face ID 开关跨重启持久化;默认笔记本可选择并记忆;iCloud 同步状态只读展示;关于卡显示真实版本号。

### Step 1:SecurityManager 加持久化

打开 `Services/SecurityManager.swift`:

- 顶部加 `private let defaults = UserDefaults.standard`、`private let isEnabledKey = "security.faceIDEnabled"`
- 新增 `init()`:
  ```swift
  init() {
      self.isEnabled = defaults.object(forKey: isEnabledKey) as? Bool ?? true
  }
  ```
- 新增 `func setEnabled(_ newValue: Bool)`:
  ```swift
  func setEnabled(_ newValue: Bool) {
      defaults.set(newValue, forKey: isEnabledKey)
      isEnabled = newValue
      if !newValue { isLocked = false }
  }
  ```
- 现有 `toggleSecurity()` 内部改为 `setEnabled(!isEnabled)`
- **若 SecurityManager 当前无 init**(继承默认 init),补 init 即可;若已有 init 含其他参数,保留其他参数,只加 UserDefaults 读取

### Step 2:SettingsView(新建文件)

创建 `dayfold/dayfold/Views/SettingsView.swift`:

```swift
struct SettingsView: View {
    @EnvironmentObject private var securityManager: SecurityManager
    @EnvironmentObject private var coreDataStack: CoreDataStack
    @Environment(\.managedObjectContext) private var viewContext

    @State private var defaultNotebookID: UUID? = SettingsStore.loadDefaultNotebookID()
    @State private var showNotebookPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                securityCard
                defaultNotebookCard
                icloudCard
                aboutCard
            }
            .padding()
        }
        .background(Color.warmPaper.ignoresSafeArea())
        .sheet(isPresented: $showNotebookPicker) {
            NotebookPickerSheet(title: "选择默认笔记本") { notebook in
                SettingsStore.saveDefaultNotebookID(notebook.id)
                defaultNotebookID = notebook.id
            }
        }
    }

    // 4 个子视图定义:
    // - securityCard: Toggle 绑 securityManager.setEnabled
    // - defaultNotebookCard: HStack 显示当前默认本名 + chevron,点击 showNotebookPicker = true
    // - icloudCard: 圆点 (warmAccent / warmGray) + 文字
    // - aboutCard: VStack 显示版本号 / build 号 / Dayfold
}

// 内嵌 private enum
private enum SettingsStore {
    static let defaultNotebookIDKey = "settings.defaultNotebookID"

    static func loadDefaultNotebookID() -> UUID? {
        guard let s = UserDefaults.standard.string(forKey: defaultNotebookIDKey) else { return nil }
        return UUID(uuidString: s)
    }
    static func saveDefaultNotebookID(_ id: UUID?) {
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: defaultNotebookIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultNotebookIDKey)
        }
    }
}
```

**关键代码片段**(完整子视图实现):
- `securityCard` 内 `Toggle(isOn: Binding(get: { securityManager.isEnabled }, set: { securityManager.setEnabled($0) }))`
- `defaultNotebookCard` 内通过 `SettingsStore` + 当前 viewContext 解析默认本名(或显示「未选择」)
- `icloudCard` 内 `Circle().fill(coreDataStack.isCloudKitAvailable ? Color.warmAccent : Color.warmGray).frame(width: 10, height: 10)`
- `aboutCard` 内 `Text("v\(Bundle.main.shortVersionString) (\(Bundle.main.versionNumber))")` + App 名

### Step 3:MainTabView 替换 .settings 分支

打开 `MainTabView.swift`:

- 定位 `.settings` 分支的 `PlaceholderView(...)`(L65-68 附近),替换为:
  ```swift
  if selectedTab == .settings {
      SettingsView()
          .transition(.paperDrop)
  }
  ```
- **不需要** `.environment(\.managedObjectContext, viewContext)`(环境已在 dayfoldApp 根层注入,SettingsView 内部 `@Environment` 拿)
- SecurityManager + CoreDataStack 由 `dayfoldApp.swift` 根层 `.environmentObject` 注入,自动继承

### Step 4:构建 + 提交

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild ... build 2>&1 | tail -5
```
期望 `** BUILD SUCCEEDED **`。SourceKit 误报忽略。

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/Views/SettingsView.swift \
        dayfold/dayfold/Services/SecurityManager.swift \
        dayfold/dayfold/Views/MainTabView.swift
git commit -m "feat(settings): 实现设置页 + Face ID 持久化 + 默认笔记本设置"
```

### 验收点

| # | 项 | 核对路径 |
|---|-----|------|
| D2.1 | 「设置」不再是占位文案 | MainTabView `.settings` 分支替换为 `SettingsView()` |
| D2.2 | 4 张卡可见 | securityCard / defaultNotebookCard / icloudCard / aboutCard |
| D2.3 | Face ID 开关持久化 | `SecurityManager.init()` 读 UserDefaults;`setEnabled` 写回 |
| D2.4 | 默认笔记本可选择并持久化 | `SettingsStore` save/load + `NotebookPickerSheet` onSelect 回调 |
| D2.5 | iCloud 状态圆点随 `isCloudKitAvailable` 切换 | warmAccent / warmGray |
| D2.6 | 版本号 + build + App 名真实 | `Bundle.main.shortVersionString / versionNumber / infoDictionary["CFBundleDisplayName"]` |
| D2.7 | 无新颜色 | 仅 warm token + 字面色 |

---

## Verification(整体阶段 D 完工后核对)

1. **构建**:`xcodebuild ... build` `** BUILD SUCCEEDED **`
2. **D1**:打开 App,抽屉 group2 选「数据统计」→ 看到 6 个维度真实数字;新建几篇 entry 后回看数字增长;软删一篇不影响(数字不变);streak 准确(连续 3 天有 entry 显示 3)
3. **D2**:抽屉「设置」→ 4 张卡显示;关闭 Face ID → 杀掉 App 重启 → 开关仍关闭;选默认笔记本 → 重启 → 仍记住;iCloud 圆点颜色对应系统设置(可在系统设置里登出 iCloud 测试);关于卡显示 v1.0 (1)
4. **回归**:阶段 A/B/C 的所有功能仍正常工作(笔记本、编辑器、TagPicker、mood、saveError、TagsView 入口+新建、EntryListView 筛选、TimelineView PhotoWall 点击)
5. **阶段 D 整体目标**:设计文档「占位页落地」验收 — 统计页展示全部维度;设置页各项可用(Face ID 开关生效、默认本可选、版本号正确)