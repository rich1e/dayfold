# 阶段 C · 搜索/导航 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) 或 superpowers:executing-plans task-by-task。本计划以 subagent-driven 模式写就——每个 task 一个 implementer subagent + spec/quality 双审 + 阶段 C 整分支宽审。Checkbox 用 `- [ ]`。

**Goal:** 让用户能(1)从侧边栏进入标签管理并新建标签;(2)在日记列表页用收藏 + 多选标签筛选条目(AND 语义);(3)在 TimelineView 的 PhotoWallView 上点击/编辑照片打开日记。

**Architecture:** 三 task 各自独立 — C1 改 SidebarTab/MainTabView/TagsView 三处入口;C2 仅改 EntryListView + 微调 TagPicker 让 TagSelectorSheet 接收 Binding<Set<Tag>>;C3 改 TimelineView + PhotoWallView/PhotoWallCell + 复用 EntryDetailView/EntryEditorView 的现有 sheet 入口。**不引入新文件、不改 ViewModel 的持久化逻辑。**

**Tech Stack:** SwiftUI + Core Data + MVVM(沿用)

## Global Constraints(全阶段不变)

- **commit message** 中文 Conventional Commits(`类型: 描述`);C1/C2/C3 各一个 commit,顺序按 C1→C2→C3。
- **构建命令**(从 `/Users/rich1e/workspace/code/dayfold/dayfold` 子目录跑,项目在该子目录):
  ```
  xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
  ```
  必须 `** BUILD SUCCEEDED **`。SourceKit 在 CLI 下对跨文件类型会误报,一律忽略,以 xcodebuild 为准。
- **环境注入规范**:sheet / fullScreenCover 内**必须**重新 `.environment(\.managedObjectContext, viewContext)`(`@Environment(\.managedObjectContext)` 拿到的 `viewContext`)。
- **暖色 token**:严格使用 `Color.warmPaper / warmCream / warmLight / warmBrown / warmAccent / warmGray / warmDark`(定义见 `Extensions/Color+Warm.swift`)。**不引入新颜色**。
- **导航容器**:本仓库全部用 `NavigationView`,新加 sheet 套同样的 `NavigationView`,不升级 NavigationStack。
- **改 VM**:`EntryListViewModel` 的 `filterPredicate()` 用 AND 复合谓词,符合产品意图,**不改**。`TagManagerViewModel.createTag` 已就绪,**不改**。
- **三个 task 互不阻塞**,可独立 dispatch 与合并;但 C2 涉及改 `TagSelectorSheet`,与 C1 各自作用域,无顺序依赖。

---

## Task C1:TagsView 导航入口 + 新建按钮

**Files:**
- Modify: `dayfold/dayfold/Views/SidebarView.swift`(`enum SidebarTab` 加 `case tags`、icon/label switch、`group1`)
- Modify: `dayfold/dayfold/Views/MainTabView.swift`(`if selectedTab == .xxx` 链加 `.tags` 分支)
- Modify: `dayfold/dayfold/Views/Tags/TagsView.swift`(toolbar 加 `+` Button + 新建 sheet + viewContext 注入)

**Interfaces:**
- Consumes: `TagEditorView(tag: Tag? = nil)` —— 已支持 `tag == nil` 走"新建"分支,无需改;`TagManagerViewModel.createTag(name:color:icon:)` 已就绪,无需改。
- Produces: 抽屉侧栏 group1 多一项「标签」,TagsView 顶部多一个 `+` 按钮。

### Step 1:SidebarTab 加 `.tags`

打开 `SidebarView.swift`:

- `enum SidebarTab`(L4-7)加 `case tags`
- `var icon: String` switch(L8-17)加 `case .tags: return "tag.fill"`
- `var label: String` switch(L19-28)加 `case .tags: return "标签"`
- `group1`(L38-39)数组加 `.tags`(在 `.photos` 之后),让侧栏 group1 顺序为 `list / photos / tags / map`

### Step 2:MainTabView 加 `.tags` 渲染分支

打开 `MainTabView.swift`:

- 找到 `if selectedTab == .xxx { ... }` 链(L41-65 起),在合适的 `.list / .photos` 附近新增:
  ```swift
  if selectedTab == .tags {
      TagsView(context: viewContext)
          .transition(.paperDrop)
  }
  ```

### Step 3:TagsView 加 `+` 按钮 + 新建 sheet

打开 `TagsView.swift`:

- TagsView 顶部加 `@Environment(\.managedObjectContext) private var viewContext`(若已有 `@FetchRequest` 同位置已有的 `@Environment`,直接补这一行)
- 加 `@State private var isPresentingNewTag = false`
- toolbar(L54-59)改为:
  ```swift
  .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
          Button { isPresentingNewTag = true } label: {
              Image(systemName: "plus")
          }
      }
      ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
  }
  ```
- View 末尾加 `.sheet(isPresented: $isPresentingNewTag) { NavigationView { TagEditorView(tag: nil).environment(\.managedObjectContext, viewContext) } }`

### Step 4:构建 + 提交

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild ... build 2>&1 | tail -5
```
期望 `** BUILD SUCCEEDED **`。SourceKit 误报忽略。

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/Views/SidebarView.swift \
        dayfold/dayfold/Views/MainTabView.swift \
        dayfold/dayfold/Views/Tags/TagsView.swift
git commit -m "feat: 在侧边栏添加标签入口,TagsView 支持新建标签"
```

### 验收点

| # | 项 | 核对路径 |
|---|-----|------|
| C1.1 | 抽屉 group1 出现「标签」 | `SidebarView.swift` group1 含 `.tags`;DrawerGroup `ForEach(tabs)` 自动渲染 |
| C1.2 | 点「标签」→ TagsView 切换 | `MainTabView` `if selectedTab == .tags { TagsView(context: viewContext).transition(.paperDrop) }` |
| C1.3 | TagsView 右上 `+` 可见 | `TagsView.swift` toolbar 新增 ToolbarItem(placement: .navigationBarTrailing) Button |
| C1.4 | 点 `+` 弹出「新建标签」 sheet | `.sheet(isPresented: $isPresentingNewTag) { TagEditorView(tag: nil) }`,TagEditorView title 由 `tag == nil` 分支决定 |
| C1.5 | 保存后 tag 进列表 | TagEditorView 调 `viewModel.createTag` 写入 CoreData,`@FetchRequest` 自动刷新 |
| C1.6 | 新建 sheet 内 context 正确 | sheet 内 `.environment(\.managedObjectContext, viewContext)` |

---

## Task C2:EntryListView 暴露筛选 UI

**Files:**
- Modify: `dayfold/dayfold/Views/Entry/EntryListView.swift`(新增 FilterBar + sheet state)
- Modify: `dayfold/dayfold/Views/Tag/TagPicker.swift`(`TagSelectorSheet` init 接 `Binding<Set<Tag>>`,与 `selectedTags: [Tag]` 兼容现有用法)

**Interfaces:**
- Consumes: `EntryListViewModel.showFavoritesOnly`、`EntryListViewModel.selectedTags: Set<Tag>`、`filterPredicate()` —— 全部已就绪,**不改 VM**。
- Produces: 列表顶部 FilterBar(收藏切换 + 标签筛选入口),标签筛选 sheet 弹出可多选标签(AND 语义)。

### Step 1:TagSelectorSheet init 改造

打开 `TagPicker.swift`,定位 `TagSelectorSheet`(L81-146 附近):

- 当前签名(推测):`TagSelectorSheet(allTags: [Tag], selectedTags: Binding<[Tag]>)` 或类似
- 改为接收 `Binding<Set<Tag>>`(与 `EntryListViewModel.selectedTags` 对齐):
  ```swift
  struct TagSelectorSheet: View {
      @Binding var selectedTags: Set<Tag>
      let allTags: [Tag]
      // ...
  }
  ```
- 内部 UI 的 chip 选中状态根据 `selectedTags.contains(tag)` 渲染
- 多选切换:`selectedTags.insert(tag)` / `selectedTags.remove(tag)`(走 Set 全量 mutate,触发 `@Published`)
- **不破坏**当前 `TagPicker` 调用方对 `[Tag]` 的使用 —— 若有别处仍传 `[Tag]` Binding,提供 `init(selectedTags: Binding<[Tag]>)` 重载或在调用点把 `[Tag]` 转 Set。本任务先评估:`TagSelectorSheet` 实际仅在 `TagPicker` 内部被消费,而 `TagPicker` 自身给编辑器用的 `selectedTags` 是 `[Tag]`(`EntryEditorViewModel.selectedTags: [Tag]`)。

**简化方案**:不改 `TagSelectorSheet` 签名,直接在 `EntryListView` 包一层 wrapper,内部维护 `@State private var tempSelection: Set<Tag>` 镜像 `viewModel.selectedTags`,sheet 内通过 `tempSelection` 多选,sheet 关闭时 `viewModel.selectedTags = tempSelection`。这样 `TagSelectorSheet` 签名零改动。**采用此方案。**

### Step 2:EntryListView 加 FilterBar

打开 `EntryListView.swift`:

- 已有 `@StateObject viewModel: EntryListViewModel`(L16)与 `@Environment(\.managedObjectContext) private var viewContext`(需确认存在,否则补)
- 加 `@State private var isPresentingTagPicker = false`
- 加 `@State private var tagSelectionDraft: Set<Tag> = []`
- 在 `body` 的 `NavigationView` 内、`ScrollView` 之前插入:
  ```swift
  private var filterBar: some View {
      HStack(spacing: 12) {
          Button {
              viewModel.showFavoritesOnly.toggle()
          } label: {
              Image(systemName: viewModel.showFavoritesOnly ? "heart.fill" : "heart")
                  .font(.system(size: 16))
                  .foregroundColor(viewModel.showFavoritesOnly ? .warmAccent : .warmBrown)
                  .frame(width: 32, height: 32)
          }
          Button {
              tagSelectionDraft = viewModel.selectedTags
              isPresentingTagPicker = true
          } label: {
              HStack(spacing: 6) {
                  Image(systemName: "tag.fill")
                  Text(viewModel.selectedTags.isEmpty
                       ? "筛选标签"
                       : "\(viewModel.selectedTags.count) 个标签")
                      .foregroundColor(viewModel.selectedTags.isEmpty ? .warmBrown : .warmAccent)
              }
              .font(.system(size: 14))
          }
          Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(Color.warmLight)
  }
  ```
- body 内 `ScrollView { ... }` 之前加 `filterBar`
- 视图末尾加:
  ```swift
  .sheet(isPresented: $isPresentingTagPicker, onDismiss: {
      viewModel.selectedTags = tagSelectionDraft
      // 清理已删 tag 的死引用
      viewModel.selectedTags = viewModel.selectedTags.filter { $0.managedObjectContext != nil }
  }) {
      NavigationView {
          TagFilterSheet(selection: $tagSelectionDraft, allTags: viewModel.allTags)
              .environment(\.managedObjectContext, viewContext)
      }
  }
  ```

### Step 3:新增本地组件 `TagFilterSheet`

在 `EntryListView.swift` 底部(私有扩展区,`#Preview` 之前)新增:

```swift
private struct TagFilterSheet: View {
    @Binding var selection: Set<Tag>
    let allTags: [Tag]

    var body: some View {
        List {
            ForEach(allTags, id: \.objectID) { tag in
                Button {
                    if selection.contains(tag) { selection.remove(tag) }
                    else { selection.insert(tag) }
                } label: {
                    HStack {
                        Text(tag.wrappedName)
                            .foregroundColor(.warmDark)
                        Spacer()
                        if selection.contains(tag) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.warmAccent)
                        }
                    }
                }
            }
        }
        .navigationTitle("筛选标签(AND)")
        .listStyle(.plain)
    }
}
```

### Step 4:`viewModel.allTags` 暴露

打开 `EntryListViewModel.swift`:

- 若当前无 `allTags` 计算属性,新增:
  ```swift
  var allTags: [Tag] {
      let req: NSFetchRequest<Tag> = Tag.fetchRequest() as! NSFetchRequest<Tag>
      req.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
      return (try? viewContext.fetch(req)) ?? []
  }
  ```
  或更简洁,使用现有 `@Published` 字段 + `allTags: [Tag] { tags }`(先看 VM 现有字段)。**实际 `EntryListViewModel` 是否持有 tags 字段要查**;若已通过 `@Published var allTags: [Tag] = []` 或类似字段持有,直接用;否则按上面 fetch 模式补全,`viewContext` 通过 `init(context:)` 注入。

### Step 5:构建 + 提交

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild ... build 2>&1 | tail -5
```

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/Views/Entry/EntryListView.swift \
        dayfold/dayfold/ViewModels/EntryListViewModel.swift
git commit -m "feat: EntryListView 暴露筛选 UI(收藏 + 多选标签 AND)"
```

### 验收点

| # | 项 | 路径 |
|---|-----|------|
| C2.1 | FilterBar 可见 | `filterBar` 渲染于 ScrollView 之前,背景 `Color.warmLight` |
| C2.2 | 收藏切换即时生效 | `viewModel.showFavoritesOnly.toggle()`,`filterPredicate` 立即重新计算 |
| C2.3 | 标签筛选入口可见 | 「筛选标签 / N 个标签」 文字 + tag.fill 图标 |
| C2.4 | 点标签筛选弹出 TagFilterSheet | `.sheet(isPresented:)` |
| C2.5 | 多选 + 关闭后回写 | `onDismiss: viewModel.selectedTags = tagSelectionDraft` |
| C2.6 | 死引用清理 | `filter { $0.managedObjectContext != nil }` |
| C2.7 | AND 语义 | `EntryListViewModel.filterPredicate` 用 `NSCompoundPredicate(andPredicateWithSubpredicates:)` —— VM 不改,沿用现有 |

---

## Task C3:TimelineView 内的 PhotoWallView 点击响应

**Files:**
- Modify: `dayfold/dayfold/Views/Timeline/TimelineView.swift`(新增 viewContext、SheetMode enum、activeSheet 状态、PhotoWallView 调用加 onSelectEntry、.sheet 分发)
- Modify: `dayfold/dayfold/Views/PhotoWall/PhotoWallCell.swift`(新增 `onEdit` 字段、contextMenu「编辑条目」绑 onEdit)
- Modify: `dayfold/dayfold/Views/PhotoWall/PhotoWallView.swift`(`PhotoWallGrid` 调用 `PhotoWallCell` 处透传 `onEdit: onNavigate`,或新增 `onEditEntry` 外部参数供 TimelineView 单独指定)

**Interfaces:**
- Consumes: `EntryDetailView(entry:)`、`EntryEditorView(context:entry:)` 现有 init(均已就绪);`PhotoWallView.onSelectEntry` 已存在。
- Produces: TimelineView 照片墙支持点击看详情、长按「编辑条目」直跳编辑 sheet,两个 sheet 通过 `SheetMode` enum 互斥。

### Step 1:TimelineView 加 viewContext + SheetMode + activeSheet

打开 `TimelineView.swift`:

- 顶部加 `@Environment(\.managedObjectContext) private var viewContext`
- 加私有 enum:
  ```swift
  private enum SheetMode: Identifiable {
      case detail(Entry)
      case edit(Entry)
      var id: String {
          switch self {
          case .detail(let e): return "detail-\(e.objectID.uriRepresentation())"
          case .edit(let e):   return "edit-\(e.objectID.uriRepresentation())"
          }
      }
  }
  ```
- 加 `@State private var activeSheet: SheetMode?`

### Step 2:PhotoWallView 调用加 onSelectEntry

定位 `TimelineView` body 内 `PhotoWallView(viewModel: ..., scrollTarget: ...)` 调用(L37 附近),改为:
```swift
PhotoWallView(
    viewModel: viewModel,
    scrollTarget: photoWallScrollTarget,
    onSelectEntry: { entry in activeSheet = .detail(entry) },
    onEditEntry: { entry in activeSheet = .edit(entry) }
)
```

### Step 3:PhotoWallView 加 onEditEntry 透传

打开 `PhotoWallView.swift`:

- 在 `var onSelectEntry: ((Entry) -> Void)?` 旁边加 `var onEditEntry: ((Entry) -> Void)?`
- `PhotoWallGrid(entries: entries, onNavigate: { entry in onSelectEntry?(entry) }, onEdit: { entry in onEditEntry?(entry) })` 透传

### Step 4:PhotoWallCell 加 onEdit + 绑 contextMenu

打开 `PhotoWallCell.swift`:

- 在 `var onTap: (Entry) -> Void = { _ in }` 旁边加 `var onEdit: (Entry) -> Void = { _ in }`
- contextMenu 中「编辑条目」空闭包(`Button { /* 跳转编辑由调用方处理 */ } label: { Label("编辑条目", systemImage: "pencil") }`)改为:
  ```swift
  Button {
      onEdit(entry)
  } label: {
      Label("编辑条目", systemImage: "pencil")
  }
  ```
- 收藏 toggle、删除等已有按钮保持原样

### Step 5:PhotoWallGrid 调用 PhotoWallCell 处加 onEdit

定位 `PhotoWallView.swift` 内 `PhotoWallGrid`(`PhotoWallCell(..., onTap: onNavigate)` 之类的调用),改为同时传 `onEdit: onEdit`(即两个回调共用函数),或按需传不同回调。

**注意**:`onEditEntry` 在 PhotoWallGrid 内部对每个 cell 调用 `PhotoWallCell` 时,传同一个 `onEdit` 函数即可(cell 自身无法区分点击与长按编辑 —— 都要进 sheet,但分别进 detail/edit)。

### Step 6:TimelineView 加 .sheet 分发

View 末尾加:
```swift
.sheet(item: $activeSheet) { mode in
    switch mode {
    case .detail(let entry):
        NavigationView { EntryDetailView(entry: entry) }
            .environment(\.managedObjectContext, viewContext)
    case .edit(let entry):
        NavigationView { EntryEditorView(context: viewContext, entry: entry) }
            .environment(\.managedObjectContext, viewContext)
    }
}
```

### Step 7:构建 + 提交

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild ... build 2>&1 | tail -5
```

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/Views/Timeline/TimelineView.swift \
        dayfold/dayfold/Views/PhotoWall/PhotoWallView.swift \
        dayfold/dayfold/Views/PhotoWall/PhotoWallCell.swift
git commit -m "feat: TimelineView PhotoWallView 支持点击查看详情与编辑"
```

### 验收点

| # | 项 | 路径 |
|---|-----|------|
| C3.1 | cell 点击 → 详情 sheet | `onSelectEntry: { entry in activeSheet = .detail(entry) }` + `.sheet(item:)` 分发 |
| C3.2 | 长按「编辑条目」 → 编辑 sheet | `onEditEntry: { entry in activeSheet = .edit(entry) }` + contextMenu 绑 `onEdit(entry)` |
| C3.3 | 两个 sheet 互斥无 runtime warning | 单一 `activeSheet: SheetMode?` 状态,enum 切换 |
| C3.4 | sheet 内 context 正确 | sheet 内 `.environment(\.managedObjectContext, viewContext)` |
| C3.5 | NotebookDetailView 的 PhotoWallView 入口不退化 | `onEditEntry` 默认 nil → PhotoWallCell `onEdit` 默认空闭包,NotebookDetailView 不传时不报错 |

---

## Verification(整体阶段 C 完工后核对)

1. **构建**:`xcodebuild ... build` `** BUILD SUCCEEDED **`
2. **C1**:打开 App,左侧抽屉滑出,group1 多「标签」,点入 TagsView,右上 `+` → 新建标签表单,保存后出现在列表
3. **C2**:侧栏「全部日记」 → FilterBar 顶部显示,点 heart 切换收藏,点「筛选标签」 → 多选标签 sheet,确认后列表过滤;多选 AND 验证:选 2 个 tag 后只有同时含 2 个 tag 的 entry 出现
4. **C3**:侧栏「时间线」(或 photo wall 入口)→ TimelineView 切到「照片」模式 → 点照片弹详情 → 长按弹 contextMenu 「编辑条目」直跳编辑 sheet;关闭详情 / 编辑互斥,无 warning
5. **回归**:阶段 A/B 的笔记本、编辑器、TagPicker、mood、saveError 全部正常工作