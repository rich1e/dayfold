# 笔记本持久化 实现计划（阶段 A）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `Notebook` 从 HomeView 内的纯 `@State` struct 落地为 Core Data 实体，实现笔记本持久化、按笔记本隔离日记、删本软删该本日记进回收站、回收站恢复时用户选目标本。

**Architecture:** 新增 `Notebook` Core Data 实体（`codeGenerationType="class"` 自动生成类），`Entry.notebook` 多对多反向关系（CloudKit 约束：两端可选 + 双向）。`CoverStyle` 枚举从 HomeView 迁到 `Models/Notebook.swift` 作为独立枚举，供自动生成的 `Notebook` 类通过计算属性桥接（实体存 `coverStyleRaw: Int32`）。HomeView 改用 `@FetchRequest<Notebook>`。新建笔记本选择器组件 `NotebookPickerSheet`，供 TrashView 恢复复用。

**Tech Stack:** SwiftUI、Core Data（`NSPersistentCloudKitContainer`）、MVVM。iOS 18.1 部署目标，iPhone 16 Pro 模拟器构建验证。

## Global Constraints

- commit message 必须用中文，遵循 Conventional Commits（`feat:` / `fix:` / `refactor:` 等）。
- 每个任务结束（或多任务合并提交前）必须运行构建，以 `xcodebuild ... BUILD SUCCEEDED` 为准，不信 SourceKit 跨文件误报：
  ```bash
  cd dayfold && xcodebuild \
    -project dayfold.xcodeproj \
    -scheme dayfold \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    build 2>&1 | tail -5
  ```
- Core Data schema 变更须严守 CloudKit 约束：**所有关系两端可选（optional="YES"）、必有反向关系（inverseName / inverseEntity）**。
- `sheet` / `fullScreenCover` 内必须再次 `.environment(\.managedObjectContext, context)`，否则子视图拿到系统默认空 context，写入不被 `@FetchRequest` 感知。
- 行内属性/关系变化的视图声明 `@ObservedObject var`；`@FetchRequest` 只感知集合增删。
- 存量数据**不迁移**（现有均为测试数据），但保留「默认笔记本兜底」防零笔记本空状态崩溃。
- Core Data `codeGenerationType="class"` 会自动生成 `Notebook` 类；HomeView 现有的 `struct Notebook` **必须先移除**，否则类型名冲突编译失败。

---

## 命名冲突背景（所有任务必读）

当前 `Views/HomeView.swift:7-32` 定义了 `struct Notebook`（含嵌套 `enum CoverStyle`、`static func make()`），并被 `NotebookCoverView`、`CoverPatternView`、`NotebookListRow`、`NotebookDetailView`（`let notebook: Notebook`）大量引用。

新增 Core Data 实体也叫 `Notebook`（`representedClassName="Notebook"`，自动生成类）。两者同名会冲突。策略：

1. 先建实体 + `Models/Notebook.swift` 扩展（Task 1、2），此时因 HomeView 里旧 struct 仍在，**会编译失败** —— 这是预期的中间态。
2. Task 3 一次性把 HomeView 及其依赖视图切到实体类型，移除旧 struct，恢复编译。

因此 Task 1→2→3 是一个不可拆的编译连续体：**Task 1、2 单独构建预期 FAILED，直到 Task 3 完成才 BUILD SUCCEEDED**。每个任务内的「构建验证」步骤已按此说明预期结果。

---

## Task 1: 新增 Notebook 实体与 Entry.notebook 关系（Core Data 模型版本）

**Files:**
- Modify: `dayfold/dayfold/dayfold.xcdatamodeld/dayfold.xcdatamodel/contents`

**Interfaces:**
- Produces: 实体 `Notebook`（`representedClassName="Notebook"`, `codeGenerationType="class"`）属性 `id: UUID?`、`name: String?`、`coverStyleRaw: Int32`、`createdAt: Date?`、`sortOrder: Int32`；关系 `Notebook.entries ⟷ Entry.notebook`（一对多，两端可选，`Notebook.entries` 删除规则 Nullify，`Entry.notebook` 删除规则 Nullify）。

> 注意：本项目 `.xcdatamodeld` 只有单一 `.xcdatamodel`（无历史版本目录）。存量数据不迁移，直接在现有模型上追加实体/关系即可（轻量迁移，属性/关系全可选，SQLite 自动推断）。

- [ ] **Step 1: 在 contents 中新增 Notebook 实体并给 Entry 加 notebook 关系**

在 `dayfold/dayfold/dayfold.xcdatamodeld/dayfold.xcdatamodel/contents` 里：

（a）给 `Entry` 实体（第 3-17 行那块）追加一条关系，放在 `location` 关系前后均可，示例放在 `mediaAssets` 之后：

```xml
        <relationship name="notebook" optional="YES" maxCount="1" deletionRule="Nullify" destinationEntity="Notebook" inverseName="entries" inverseEntity="Notebook"/>
```

（b）在 `</entity>`（Tag 实体结束）之后、`</model>` 之前，新增 Notebook 实体：

```xml
    <entity name="Notebook" representedClassName="Notebook" syncable="YES" codeGenerationType="class">
        <attribute name="coverStyleRaw" optional="YES" attributeType="Integer 32" defaultValueString="0" usesScalarValueType="YES"/>
        <attribute name="createdAt" optional="YES" attributeType="Date" usesScalarValueType="NO"/>
        <attribute name="id" optional="YES" attributeType="UUID" usesScalarValueType="NO"/>
        <attribute name="name" optional="YES" attributeType="String"/>
        <attribute name="sortOrder" optional="YES" attributeType="Integer 32" defaultValueString="0" usesScalarValueType="YES"/>
        <relationship name="entries" optional="YES" toMany="YES" deletionRule="Nullify" destinationEntity="Entry" inverseName="notebook" inverseEntity="Entry"/>
    </entity>
```

- [ ] **Step 2: 构建验证（预期 FAILED，因命名冲突）**

Run:
```bash
cd dayfold && xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -15
```
Expected: **BUILD FAILED**，报错类似 `invalid redeclaration of 'Notebook'`（自动生成的 `Notebook` 类与 HomeView 内 `struct Notebook` 冲突）。这是预期中间态，Task 3 修复。若报的是**其他**错误（如 xml 解析失败、实体名拼写错），先修正 xml。

- [ ] **Step 3: 提交**

```bash
git add dayfold/dayfold/dayfold.xcdatamodeld/dayfold.xcdatamodel/contents
git commit -m "feat: 新增 Notebook 实体与 Entry.notebook 关系"
```

---

## Task 2: Notebook 模型扩展 + CoverStyle 枚举迁出

**Files:**
- Create: `dayfold/dayfold/Models/Notebook.swift`

**Interfaces:**
- Consumes: Task 1 自动生成的 `Notebook` 类（属性 `id`、`name`、`coverStyleRaw`、`createdAt`、`sortOrder`、`entries`）。
- Produces:
  - 独立枚举 `NotebookCoverStyle: Int, CaseIterable`，含 `chevronTeal/triangleRed/stripesBlack/leatherBrown/diagonalGray`，属性 `var spineColor: Color`。
  - `Notebook` 扩展：`var wrappedName: String`、`var coverStyle: NotebookCoverStyle`（get/set 桥接 `coverStyleRaw`）、`var entriesArray: [Entry]`（按 createdAt 倒序、过滤 `deletedAt == nil`）、`static func create(name:style:in:) -> Notebook`、`func deleteWithEntriesToTrash(in:)`。

> 命名决策：枚举从 `Notebook.CoverStyle` 迁为**顶层** `NotebookCoverStyle`（不能再嵌套在 struct 里，因为 struct 被删除；也不宜作为 Core Data 生成类的嵌套类型）。Task 3 会把所有 `Notebook.CoverStyle` / `.CoverStyle` 引用改为 `NotebookCoverStyle`。

- [ ] **Step 1: 创建 Models/Notebook.swift**

```swift
// Models/Notebook.swift
import Foundation
import CoreData
import SwiftUI

// MARK: - 封面样式（从 HomeView 的 struct Notebook 迁出为顶层枚举）

enum NotebookCoverStyle: Int, CaseIterable {
    case chevronTeal, triangleRed, stripesBlack, leatherBrown, diagonalGray

    var spineColor: Color {
        switch self {
        case .chevronTeal:   return Color(hex: "8A8A90")
        case .triangleRed:   return Color(hex: "C04030")
        case .stripesBlack:  return Color(hex: "303035")
        case .leatherBrown:  return Color(hex: "2C1A0A")
        case .diagonalGray:  return Color(hex: "606065")
        }
    }
}

// MARK: - Notebook 实体扩展

extension Notebook {
    var wrappedName: String {
        name ?? "UNTITLED"
    }

    var coverStyle: NotebookCoverStyle {
        get { NotebookCoverStyle(rawValue: Int(coverStyleRaw)) ?? .chevronTeal }
        set { coverStyleRaw = Int32(newValue.rawValue) }
    }

    /// 本笔记本下未软删的日记，按创建时间倒序
    var entriesArray: [Entry] {
        let set = entries as? Set<Entry> ?? []
        return set
            .filter { $0.deletedAt == nil }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }

    static func create(name: String, style: NotebookCoverStyle, in context: NSManagedObjectContext) -> Notebook {
        let nb = Notebook(context: context)
        nb.id = UUID()
        nb.name = name
        nb.coverStyle = style
        nb.createdAt = Date()
        nb.sortOrder = 0
        return nb
    }

    /// 删除笔记本：本下未软删日记逐个移入回收站，再删本实体（entries 关系因 Nullify 自动解绑）。
    /// 不物理删除日记与图片；物理去留由回收站永久删除逻辑负责。
    func deleteWithEntriesToTrash(in context: NSManagedObjectContext) {
        for entry in entriesArray {
            entry.moveToTrash()
        }
        context.delete(self)
    }
}
```

- [ ] **Step 2: 构建验证（预期 FAILED，命名冲突未消除）**

Run:
```bash
cd dayfold && xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -15
```
Expected: **BUILD FAILED**，仍报 `Notebook` redeclaration（HomeView struct 未移除）。确认报错**只**围绕 `struct Notebook` / `Notebook.CoverStyle` 冲突，不含 `Notebook.swift` 自身语法错。若 `Notebook.swift` 报语法错，先修。

- [ ] **Step 3: 提交**

```bash
git add dayfold/dayfold/Models/Notebook.swift
git commit -m "feat: 新增 Notebook 模型扩展与 NotebookCoverStyle 枚举"
```

---

## Task 3: HomeView 切换到 Notebook 实体（移除旧 struct，恢复编译）

**Files:**
- Modify: `dayfold/dayfold/Views/HomeView.swift`
- Modify: `dayfold/dayfold/Views/NotebookDetailView.swift`（仅类型引用 + Preview，谓词在 Task 5）

**Interfaces:**
- Consumes: `Notebook` 实体（Task 1）、`NotebookCoverStyle` + `Notebook.create` / `deleteWithEntriesToTrash`（Task 2）。
- Produces: HomeView 用 `@FetchRequest<Notebook>` 管理笔记本；`NotebookCoverView` / `CoverPatternView` / `NotebookListRow` 改用 `NotebookCoverStyle`。`NotebookDetailView` 的 `let notebook: Notebook` 现指向实体类型（@ObservedObject）。

- [ ] **Step 1: 删除 HomeView 内的 struct Notebook**

删除 `Views/HomeView.swift` 第 5-32 行整块（`// MARK: - 笔记本数据模型` 到 struct 结束）。

- [ ] **Step 2: HomeView 改用 @FetchRequest<Notebook>**

将 `HomeView` 的 `@State private var notebooks: [Notebook] = [...]` 替换为 FetchRequest，并把 `currentNotebook` 改为按 fetch 结果索引。替换后的相关成员：

```swift
struct HomeView: View {
    let context: NSManagedObjectContext
    @Binding var isListMode: Bool
    var onNewEntry: () -> Void

    @State private var currentIndex: Int = 0
    @State private var confirmDelete = false
    @State private var showDetail = false
    @Namespace private var coverNamespace

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Notebook.sortOrder, ascending: true),
                          NSSortDescriptor(keyPath: \Notebook.createdAt, ascending: true)],
        animation: .default
    ) private var notebooks: FetchedResults<Notebook>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Entry.createdAt, ascending: false)],
        animation: .default
    ) private var entries: FetchedResults<Entry>

    var currentNotebook: Notebook? {
        guard notebooks.indices.contains(currentIndex) else { return nil }
        return notebooks[currentIndex]
    }
```

（`entryCount` / `latestDate` 保持不变。`ForEach(Array(notebooks.enumerated()), id: \.element.id)` 因 `Notebook` 是 NSManagedObject 且 `id: UUID?` 可选——改用 `id: \.element.objectID` 更稳：`ForEach(Array(notebooks.enumerated()), id: \.element.objectID)`。两处 ForEach（封面翻页 / 列表模式）都改。）

- [ ] **Step 3: 改 addNotebook / deleteCurrentNotebook 走 Core Data**

```swift
    private func addNotebook() {
        let styles = NotebookCoverStyle.allCases
        let usedStyles = notebooks.map { Int($0.coverStyleRaw) }
        let nextStyle = styles.first(where: { !usedStyles.contains($0.rawValue) }) ?? styles[notebooks.count % styles.count]
        let nb = Notebook.create(name: "UNTITLED", style: nextStyle, in: context)
        nb.sortOrder = Int32(notebooks.count)
        try? CoreDataStack.shared.save()
        currentIndex = notebooks.count - 1
    }

    private func deleteCurrentNotebook() {
        guard notebooks.indices.contains(currentIndex) else { return }
        let nb = notebooks[currentIndex]
        nb.deleteWithEntriesToTrash(in: context)
        try? CoreDataStack.shared.save()
        if currentIndex >= notebooks.count {
            currentIndex = max(0, notebooks.count - 1)
        }
    }
```

- [ ] **Step 4: 把封面/列表子视图的 CoverStyle 引用改为 NotebookCoverStyle**

在 `HomeView.swift` 内：
- `NotebookCoverView`：`let notebook: Notebook`（现为实体，保持 `let`，改声明为 `@ObservedObject var notebook: Notebook`）。`notebook.coverStyle`、`notebook.coverStyle.spineColor` 引用不变（Task 2 扩展提供）。
- `private struct CoverPatternView { let style: Notebook.CoverStyle }` → `let style: NotebookCoverStyle`，`switch style` 分支不变。
- `NotebookListRow`：`let notebook: Notebook` → `@ObservedObject var notebook: Notebook`；`notebook.name` → `notebook.wrappedName`；`CoverPatternView(style: notebook.coverStyle)` 不变。
- 移除文件内所有对 `Notebook.make(...)`、`Notebook.CoverStyle` 的引用；`#Preview` 里 `Notebook.make(style:)` 改为在预览 context 里 `Notebook.create(name:"预览",style:.chevronTeal,in:CoreDataStack.shared.viewContext)`。

- [ ] **Step 5: NotebookDetailView 类型引用与 Preview 更新**

在 `Views/NotebookDetailView.swift`：
- `let notebook: Notebook` → `@ObservedObject var notebook: Notebook`（实体类型；`init` 里 `self.notebook = notebook` 不变）。
- 标题 `Text(notebook.name)` → `Text(notebook.wrappedName)`。
- `#Preview` 里 `Notebook.make(style: .chevronTeal)` → `Notebook.create(name: "预览", style: .chevronTeal, in: context)`。
- 谓词暂不动（Task 5 处理）。

- [ ] **Step 6: 构建验证（预期 SUCCEEDED）**

Run:
```bash
cd dayfold && xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: **BUILD SUCCEEDED**。命名冲突消除，编译恢复。若仍有 `Notebook.CoverStyle` / `Notebook.make` 残留引用报错，逐个改为 `NotebookCoverStyle` / `Notebook.create`。

- [ ] **Step 7: 提交**

```bash
git add dayfold/dayfold/Views/HomeView.swift dayfold/dayfold/Views/NotebookDetailView.swift
git commit -m "refactor: HomeView 笔记本改用 Core Data 实体，移除内联 struct"
```

---

## Task 4: 默认笔记本种子 + 首启兜底

**Files:**
- Modify: `dayfold/dayfold/Services/CoreDataStack.swift`

**Interfaces:**
- Consumes: `Notebook.create`（Task 2）。
- Produces: `func ensureDefaultNotebook()`（无笔记本时种一个「我的日记」默认本），参照现有 `createPresetTags()` 幂等模式。

- [ ] **Step 1: 加 ensureDefaultNotebook 方法**

在 `CoreDataStack` 内 `createPresetTags()` 之后新增：

```swift
    func ensureDefaultNotebook() {
        let context = viewContext
        let request: NSFetchRequest<Notebook> = Notebook.fetchRequest()
        do {
            let count = try context.count(for: request)
            guard count == 0 else { return }
            let nb = Notebook.create(name: "我的日记", style: .chevronTeal, in: context)
            nb.sortOrder = 0
            try save()
            print("Default notebook created")
        } catch {
            print("Failed to ensure default notebook: \(error.localizedDescription)")
        }
    }
```

- [ ] **Step 2: 在 App 首启调用**

现有 `createPresetTags()` 的调用点在解锁成功后（见 IMPLEMENTATION_PROGRESS：`M->>M: coreDataStack.createPresetTags()`）。找到该调用处（`grep -rn "createPresetTags" dayfold/dayfold`），在其**紧随其后**加一行：

```swift
coreDataStack.ensureDefaultNotebook()
```

（若 `createPresetTags` 调用在 `MainTabView`/`dayfoldApp` 的 `.onAppear` 或 `.task` 中，就在同一闭包内 `createPresetTags()` 之后追加。）

- [ ] **Step 3: 构建验证**

Run:
```bash
cd dayfold && xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: **BUILD SUCCEEDED**。

- [ ] **Step 4: 提交**

```bash
git add dayfold/dayfold/Services/CoreDataStack.swift dayfold/dayfold/dayfoldApp.swift dayfold/dayfold/Views/MainTabView.swift
git commit -m "feat: 首启种子默认笔记本，兜底防零笔记本空状态"
```
（`git add` 覆盖种子调用点所在文件，按实际改动的文件增删。）

---

## Task 5: NotebookDetailView 按笔记本隔离日记

**Files:**
- Modify: `dayfold/dayfold/Views/NotebookDetailView.swift`

**Interfaces:**
- Consumes: `Notebook` 实体、`Entry.notebook` 关系。
- Produces: NotebookDetailView 的 `@FetchRequest` 谓词加 `notebook == %@`，只显示本笔记本下未软删日记。

> `@FetchRequest` 的谓词需依赖 `notebook`（init 传入），SwiftUI 属性包装器不能直接用实例成员初始化谓词——须在 `init` 内用 `_entries = FetchRequest(...)` 手动构造。

- [ ] **Step 1: 改 init 内构造带 notebook 谓词的 FetchRequest**

将当前 `@FetchRequest(...)` 声明（NotebookDetailView.swift:24-28）改为无默认值的 `@FetchRequest private var entries: FetchedResults<Entry>`，并在 `init` 内构造：

```swift
    @FetchRequest private var entries: FetchedResults<Entry>

    init(notebook: Notebook, onNewEntry: @escaping () -> Void, isPresented: Binding<Bool>) {
        self.notebook = notebook
        self.onNewEntry = onNewEntry
        self._isPresented = isPresented
        self._timelineVM = StateObject(wrappedValue: TimelineViewModel(context: CoreDataStack.shared.viewContext))
        self._entries = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Entry.createdAt, ascending: false)],
            predicate: NSPredicate(format: "deletedAt == nil AND notebook == %@", notebook),
            animation: .default
        )
    }
```

（`notebook` 已在 Task 3 改为 `@ObservedObject var notebook: Notebook`，`self.notebook = notebook` 赋值不变。）

- [ ] **Step 2: 构建验证**

Run:
```bash
cd dayfold && xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: **BUILD SUCCEEDED**。

- [ ] **Step 3: 提交**

```bash
git add dayfold/dayfold/Views/NotebookDetailView.swift
git commit -m "feat: NotebookDetailView 按笔记本隔离日记查询"
```

---

## Task 6: 新建日记写入所属笔记本

**Files:**
- Modify: `dayfold/dayfold/ViewModels/EntryEditorViewModel.swift`
- Modify: `dayfold/dayfold/Views/Entry/EntryEditorView.swift`
- Modify: `dayfold/dayfold/Views/NotebookDetailView.swift`（`.newEntry` 传 notebook）
- Modify: `dayfold/dayfold/Views/MainTabView.swift`（全局新建入口落默认本）

**Interfaces:**
- Consumes: `Notebook` 实体。
- Produces: `EntryEditorViewModel.init(context:entry:prefillDate:notebook:)` 新增 `notebook: Notebook? = nil` 参数；`save()` 新建时写 `entryToSave.notebook`。`EntryEditorView.init(entry:context:prefillDate:notebook:)` 透传。

> 编辑既有日记时不改 notebook（保持归属）。仅新建（`entry == nil`）时设置。

- [ ] **Step 1: EntryEditorViewModel 加 notebook 参数并在 save 写入**

在 `EntryEditorViewModel`：
- 加存储属性 `private let notebook: Notebook?`。
- `init` 签名加 `notebook: Notebook? = nil`，函数体 `self.notebook = notebook`（放在 `self.prefillDate = prefillDate` 后）。
- `save()` 中新建分支（`else { entryToSave = Entry.create(...) ... }`）里，创建 entry 后加：

```swift
            if let notebook = notebook {
                entryToSave.notebook = notebook
            }
```

放在 `entry = entryToSave` 前。

- [ ] **Step 2: EntryEditorView 透传 notebook**

`EntryEditorView.init`：

```swift
    init(entry: Entry? = nil, context: NSManagedObjectContext, prefillDate: Date? = nil, notebook: Notebook? = nil) {
        _viewModel = StateObject(wrappedValue: EntryEditorViewModel(
            context: context, entry: entry, prefillDate: prefillDate, notebook: notebook))
    }
```

- [ ] **Step 3: NotebookDetailView 的 .newEntry 传当前 notebook**

`Views/NotebookDetailView.swift` 的 `.sheet` 内 `.newEntry` 分支（当前 `EntryEditorView(context: context)`）改为：

```swift
            case .newEntry:
                EntryEditorView(context: context, notebook: notebook)
                    .environment(\.managedObjectContext, context)
```

- [ ] **Step 4: MainTabView 全局新建入口落默认本**

`Views/MainTabView.swift` 顶层 `.sheet(isPresented: $showingNewEntry)`（当前 `EntryEditorView(context: viewContext)`）。全局入口无笔记本上下文，落到第一个（默认）笔记本。加一个 fetch 助手：

```swift
    private var defaultNotebook: Notebook? {
        let request: NSFetchRequest<Notebook> = Notebook.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Notebook.sortOrder, ascending: true)]
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }
```

并把 sheet 改为：

```swift
        .sheet(isPresented: $showingNewEntry) {
            EntryEditorView(context: viewContext, notebook: defaultNotebook)
                .environment(\.managedObjectContext, viewContext)
        }
```

（顶部 `import CoreData` 若缺失需补。）

- [ ] **Step 5: 构建验证**

Run:
```bash
cd dayfold && xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: **BUILD SUCCEEDED**。

- [ ] **Step 6: 提交**

```bash
git add dayfold/dayfold/ViewModels/EntryEditorViewModel.swift dayfold/dayfold/Views/Entry/EntryEditorView.swift dayfold/dayfold/Views/NotebookDetailView.swift dayfold/dayfold/Views/MainTabView.swift
git commit -m "feat: 新建日记写入所属笔记本，全局入口落默认本"
```

---

## Task 7: 笔记本选择器组件 NotebookPickerSheet

**Files:**
- Create: `dayfold/dayfold/Views/Common/NotebookPickerSheet.swift`

**Interfaces:**
- Consumes: `Notebook` 实体、`NotebookCoverStyle`。
- Produces: `NotebookPickerSheet`，`init(title: String, onSelect: @escaping (Notebook) -> Void)`；内部 `@FetchRequest<Notebook>` 列出所有本，含「新建笔记本」入口（无本或用户想新建时用 `Notebook.create` 建一个默认样式本并回调）。

> 用现有暖色深色主题 token（`Color(hex:)` 直用截图配色：背景 `#2A2A30`，卡片 `#32323A`，主文字 `#E8E8EC`，青强调 `#5BC8D8`），与 TrashView / NotebookDetailView 保持一致。Stitch 稿恢复后可替换视觉，接口不变。

- [ ] **Step 1: 创建 NotebookPickerSheet.swift**

```swift
// Views/Common/NotebookPickerSheet.swift
import SwiftUI
import CoreData

struct NotebookPickerSheet: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSelect: (Notebook) -> Void

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Notebook.sortOrder, ascending: true),
                          NSSortDescriptor(keyPath: \Notebook.createdAt, ascending: true)],
        animation: .default
    ) private var notebooks: FetchedResults<Notebook>

    var body: some View {
        ZStack {
            Color(hex: "2A2A30").ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶栏
                HStack {
                    Button("取消") { dismiss() }
                        .foregroundColor(Color(hex: "9090A0"))
                    Spacer()
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "E8E8EC"))
                    Spacer()
                    Button {
                        createAndSelect()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Color(hex: "5BC8D8"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(notebooks, id: \.objectID) { nb in
                            Button {
                                onSelect(nb)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(nb.coverStyle.spineColor)
                                        .frame(width: 32, height: 32)
                                    Text(nb.wrappedName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "E8E8EC"))
                                    Spacer()
                                    Text("\(nb.entriesArray.count)")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "7A7A88"))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(hex: "32323A"))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func createAndSelect() {
        let nb = Notebook.create(name: "UNTITLED", style: .chevronTeal, in: context)
        nb.sortOrder = Int32(notebooks.count)
        try? CoreDataStack.shared.save()
        onSelect(nb)
        dismiss()
    }
}

#Preview {
    NotebookPickerSheet(title: "恢复到笔记本", onSelect: { _ in })
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
```

- [ ] **Step 2: 构建验证**

Run:
```bash
cd dayfold && xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: **BUILD SUCCEEDED**。

- [ ] **Step 3: 提交**

```bash
git add dayfold/dayfold/Views/Common/NotebookPickerSheet.swift
git commit -m "feat: 新增笔记本选择器组件 NotebookPickerSheet"
```

---

## Task 8: 回收站恢复时选目标笔记本

**Files:**
- Modify: `dayfold/dayfold/Views/Entry/TrashView.swift`

**Interfaces:**
- Consumes: `NotebookPickerSheet`（Task 7）、`Entry.restore()`、`Entry.notebook`。
- Produces: TrashView 恢复流程改为：点「恢复」→ 弹 `NotebookPickerSheet` → 选本后 `entry.restore()` + `entry.notebook = 选中本` + save。

- [ ] **Step 1: 加恢复目标状态与选本 sheet**

在 `TrashView` 加：

```swift
    @State private var restoringEntry: Entry?
```

- [ ] **Step 2: 改 restore 流程为先记录待恢复条目**

将现有 `restore(_:)` 改为只暂存条目、触发选本：

```swift
    private func restore(_ entry: Entry) {
        restoringEntry = entry
    }
```

在 `body` 的 `.confirmationDialog` 后追加：

```swift
        .sheet(item: $restoringEntry) { entry in
            NotebookPickerSheet(title: "恢复到笔记本") { notebook in
                entry.restore()
                entry.notebook = notebook
                try? viewContext.save()
            }
            .environment(\.managedObjectContext, viewContext)
        }
```

> `Entry` 需符合 `Identifiable` 才能用 `.sheet(item:)`。`NSManagedObject` 不自动符合。改用绑定包装：新增私有 `Identifiable` 包装，或给 `restoringEntry` 用 objectID 驱动。**采用**：把 `restoringEntry` 改为 `@State private var restoringEntry: EntryRef?`，其中：

```swift
    private struct EntryRef: Identifiable {
        let id: NSManagedObjectID
        let entry: Entry
    }
```

`restore(_:)` 内 `restoringEntry = EntryRef(id: entry.objectID, entry: entry)`；sheet 闭包参数改用 `ref in`，内部 `ref.entry.restore()` / `ref.entry.notebook = notebook`。

- [ ] **Step 3: 构建验证**

Run:
```bash
cd dayfold && xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: **BUILD SUCCEEDED**。

- [ ] **Step 4: 提交**

```bash
git add dayfold/dayfold/Views/Entry/TrashView.swift
git commit -m "feat: 回收站恢复时弹选择器指定目标笔记本"
```

---

## Task 9: 端到端手动验证与回归

**Files:**（无代码改动，纯验证；如发现 bug 则回到对应 Task 修复）

- [ ] **Step 1: 构建 + 启动模拟器**

Run:
```bash
cd dayfold && xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
Expected: **BUILD SUCCEEDED**。（如需交互验证，在模拟器运行 App。）

- [ ] **Step 2: 逐条核对验收标准**

按 spec 第五节「A」验收标准手动核对：
1. 重启 App 后笔记本列表保留（持久化生效）。
2. 建 ≥2 个笔记本，各自新建日记，进不同本只看到各自日记（隔离生效）。
3. 全局新建入口（MainTabView 顶部/抽屉外的 +）建的日记落到默认本。
4. 删某笔记本 → 该本日记从所有笔记本视图消失，出现在回收站。
5. 回收站点「恢复」→ 弹选本器 → 选定本 → 日记回到该本。
6. 删到零笔记本边界不崩溃（应始终有默认本兜底；若删了默认本，确认恢复选本器有「新建」入口）。

- [ ] **Step 3: 记录结果**

在 `docs/IMPLEMENTATION_PROGRESS.md` 追加「阶段 A · 笔记本持久化」小节，按文件汇总改动与验证结果。提交：

```bash
git add docs/IMPLEMENTATION_PROGRESS.md
git commit -m "docs: 记录阶段 A 笔记本持久化实现进度"
```

---

## Self-Review 记录

- **Spec 覆盖**：spec 阶段 A 的 5 项代码改造 + 删本逻辑 + 恢复选本逻辑，分别落在 Task 1（schema）/2（模型）/3（HomeView）/4（种子）/5（隔离谓词）/6（写入归属）/7-8（选本恢复）。默认本兜底 = Task 4。存量不迁移 = 全程未加迁移代码。✅
- **占位扫描**：无 TBD / 「适当处理」类占位；每个代码步骤给出完整代码或精确改动位置。✅
- **类型一致性**：`NotebookCoverStyle`（Task 2 定义）在 Task 3/7 引用一致；`Notebook.create(name:style:in:)` 签名在 Task 2/3/4/7 一致；`EntryEditorViewModel.init(...notebook:)` 在 Task 6 定义并透传；`deleteWithEntriesToTrash(in:)` Task 2 定义、Task 3 调用一致。✅
- **命名冲突风险**已在专节 + Task 1/2/3 预期结果中显式说明（中间态预期 FAILED）。
