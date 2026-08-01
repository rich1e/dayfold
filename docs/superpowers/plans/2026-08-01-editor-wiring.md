# 阶段 B · 编辑器接线 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 MarkdownEditor + FormattingToolbar 接入日记编辑器,挂上 TagPicker 与 mood 控件,接通保存失败提示,并实现「取消按钮」——新建抹除草稿、编辑按快照完整回滚(含图片)。完成后用户在 `EntryEditorView` 内可使用 Markdown 格式化 / 选标签 / 选心情 / 取消真正放弃。

**Architecture:**
- 编辑器 View (`EntryEditorView`) 是 UI 装配层,只做组合与状态绑定,不改业务逻辑。
- 编辑器 ViewModel (`EntryEditorViewModel`) 是逻辑核心:管快照、延迟删图、保存错误传递、mood 字段。
- 复用既有组件 `MarkdownEditor` / `FormattingToolbar` / `TagPicker` —— 内部暖色调保持不变,与编辑器的暖色深色并存。
- 阶段 B 不动 Core Data schema、不动 CloudKit 容器、不新建组件。

**Tech Stack:** SwiftUI (iOS 18.1), Core Data (现有 `Entry.mood` 字段已就绪), MVVM。

## Global Constraints

- **commit message 必须使用中文**,格式遵循 Conventional Commits:`类型: 描述`。示例:`feat: 编辑器接入 MarkdownEditor 与 FormattingToolbar`。
- **每个 task 结束后必须 `xcodebuild ... build` BUILD SUCCEEDED**(见 CLAUDE.md「构建与验证」)。
- **SourceKit 跨文件类型误报忽略**,以 `xcodebuild` 结果为准。
- **保持组件原状**:MarkdownEditor/FormattingToolbar/TagPicker 内部暖色调 `Color.warmXxx` 不改,与编辑器的暖色深色(`editorBg` / `editorText` / `editorSub` / `accentCyan`)共存,接受两种风格并存。
- **mood 控件形式**:5 个 SF Symbol 一排点选(用户决策),仅存名字字符串到 `Entry.mood`,无图标变化、不带 emoji 字符。
- **不新建文件**:本计划不新增任何 .swift 文件,所有改动落在 `EntryEditorView.swift` 与 `EntryEditorViewModel.swift`。
- **图片延迟删除(B3)**:本阶段技术重点,见 Task B3 的实现要点。
- **取消语义(方案 b)**:新建日记未 auto-save → 直接 dismiss;已 auto-save → 物理删除 Entry 与其 MediaAsset 磁盘文件与 Location,**不进回收站**;编辑既有日记 → 按 EntrySnapshot 完整回滚(含图片)。
- **保留现有守卫**:`save()` 中 `title.isEmpty && content.isEmpty` 双空跳过保存逻辑保留。

---

## Task B0: 入库阶段 0 产物（设计资源）

**Files:**
- Create: `.gitignore` 追加忽略 `.stitch/`(设计稿 staging 区不入库)
- Track: `docs/PROJECT_OVERVIEW.md` → 设计资源
- Track: `docs/stitch-assets/labeled-screens.json` + `docs/stitch-assets/re-dayfold/` → 设计资源

**目的:** 设计稿入库,后续阶段 B/C/D 可引用;`.stitch/` 是 Stitch MCP 的 staging 区,只在本机用。

- [ ] **Step 1: 把 .stitch/ 加入 .gitignore**

在 `/Users/rich1e/workspace/code/dayfold/.gitignore` 末尾追加:

```
# Stitch staging
.stitch/
```

- [ ] **Step 2: 检查可入库内容**

确认以下文件存在且状态是 untracked:
- `docs/PROJECT_OVERVIEW.md`
- `docs/stitch-assets/labeled-screens.json`
- `docs/stitch-assets/re-dayfold/`(目录,内含子文件)

若是 .stitch/ 内除 DESIGN.md 之外的文件,不参与入库。

- [ ] **Step 3: 入库设计资源**

```bash
cd /Users/rich1e/workspace/code/dayfold
git add docs/PROJECT_OVERVIEW.md docs/stitch-assets/
git status
```

期望:`docs/PROJECT_OVERVIEW.md` 与 `docs/stitch-assets/**` 列入待提交,`.stitch/` 因 .gitignore 不出现。

- [ ] **Step 4: 提交**

```bash
git commit -m "docs: 入库阶段 0 设计资源与项目总览"
```

无 BUILD 验证(纯资源文件)。

---

## Task B1: MarkdownEditor + FormattingToolbar 接入编辑器

**Files:**
- Modify: `dayfold/dayfold/Views/Entry/EntryEditorView.swift` (line 121-157 editorArea; line 211-213 keyboardToolbar)

**目的:** 把正文编辑从原生 TextEditor 替换为已有 MarkdownEditor(自带 FormattingToolbar 7 个格式按钮)。删除 keyboardToolbar 中重复的 textformat 占位按钮。

- [ ] **Step 1: 替换 TextEditor 为 MarkdownEditor**

打开 `dayfold/dayfold/Views/Entry/EntryEditorView.swift`,在 `editorArea` 计算属性(line 121-157)中:

- 删除原 line 136-143 的 `TextEditor(text: $viewModel.content)` 块(8 行)
- 在该位置插入 `MarkdownEditor(text: $viewModel.content, wordCount: viewModel.wordCount, readingTime: viewModel.readingTime)`

注意:`MarkdownEditor` 内部已挂 FormattingToolbar、状态栏(字数/阅读时间)、全屏模式。**不要**再包一层 ScrollView,MarkdownEditor 自带 ScrollView;但当前 editorArea 已被 ScrollView 包了一层,需要把 ScrollView 结构调整为 MarkdownEditor 不再嵌套在另一 ScrollView 内(否则出现双滚动条)。

推荐做法:把 editorArea 内部原 ScrollView 改为 VStack(去掉外层滚动),MarkdownEditor 占正文中段(占 minHeight 320 自适应)。

- [ ] **Step 2: 删除 keyboardToolbar 中重复的 textformat 按钮**

打开同一文件,定位 `keyboardToolbar` 计算属性(line 191-219),找到:

```swift
// 格式（占位）
toolbarButton(icon: "textformat") {}
```

删除这两行(含上面注释)。`paperclip` 占位按钮**保留**(本阶段不在范围内)。

- [ ] **Step 3: 调整 ContentView 滚动结构**

确认编辑器主区域(原 ScrollView)替换为:

```swift
private var editorArea: some View {
    VStack(alignment: .leading, spacing: 0) {
        // 标题
        TextField(...)
            .padding(...)

        // 正文 MarkdownEditor
        MarkdownEditor(text: $viewModel.content,
                       wordCount: viewModel.wordCount,
                       readingTime: viewModel.readingTime)
            .frame(minHeight: 320)

        // 已选图片预览(保留)
        if !viewModel.images.isEmpty {
            imagePreviewRow
                .padding(.horizontal, 16)
                .padding(.top, 12)
        }

        // 键盘工具栏高度占位
        Spacer().frame(height: 56)
    }
    .background(editorBg)
}
```

移除原 ScrollView 包裹(避免与 MarkdownEditor 内置 ScrollView 冲突)。

- [ ] **Step 4: 跑构建验证**

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -5
```

期望:`** BUILD SUCCEEDED **`。

- [ ] **Step 5: 提交**

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/Views/Entry/EntryEditorView.swift
git commit -m "feat: 编辑器接入 MarkdownEditor 与 FormattingToolbar"
```

---

## Task B2: TagPicker 挂载编辑器

**Files:**
- Modify: `dayfold/dayfold/Views/Entry/EntryEditorView.swift` (editorArea 中,MarkdownEditor 与图片预览之间)

**目的:** 在 MarkdownEditor 下方插入 TagPicker,绑定 viewModel.selectedTags。TagPicker 与 FormattingToolbar 的暖色系独立呈现,与编辑器暖色深色共存。

- [ ] **Step 1: 在 editorArea 中插入 TagPicker**

打开 `dayfold/dayfold/Views/Entry/EntryEditorView.swift`,在 `editorArea` 内 MarkdownEditor 之后、`if !viewModel.images.isEmpty { imagePreviewRow ... }` 之前(或之后,二选一,推荐放图片预览之后),插入:

```swift
// 标签选择
TagPicker(selectedTags: $viewModel.selectedTags)
    .padding(.horizontal, 16)
    .padding(.top, 12)
```

注意:`TagPicker` 内部 `@Environment(\.managedObjectContext)` 通过 sheet 内注入的 viewContext 自动取到。`EntryEditorView` 在所有调用方都已 `.environment(\.managedObjectContext, viewContext)` 注入过(阶段 A 已确认),`TagSelectorSheet` 内的 `@FetchRequest<Tag>` 可正常取数据。

- [ ] **Step 2: 跑构建验证**

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -5
```

期望:`** BUILD SUCCEEDED **`。

- [ ] **Step 3: 验证 VM 接口(读源码)**

打开 `dayfold/dayfold/ViewModels/EntryEditorViewModel.swift`,确认:
- `@Published var selectedTags: [Tag]`(line 12)存在
- `addTag(_:)` / `removeTag(_:)`(line 174-182)存在
- `save()` 中 `entryToSave.tags = NSSet(array: selectedTags)`(line 130)存在

无需改动。若缺,补齐。

- [ ] **Step 4: 提交**

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/Views/Entry/EntryEditorView.swift
git commit -m "feat: 编辑器挂载 TagPicker 选标签"
```

---

## Task B3: 取消按钮 + 图片延迟删除 + saveError 接通（重头）

**Files:**
- Modify: `dayfold/dayfold/ViewModels/EntryEditorViewModel.swift` (整体 save 逻辑、添加 snapshot、添加 cancel、改错误处理)
- Modify: `dayfold/dayfold/Views/Entry/EntryEditorView.swift` (topBar 加取消按钮,接通 showingSaveError)

**目的:** 实现「取消真正放弃」语义(设计稿决策 #5),并把当前 auto-save 中「立即删旧图」改为「完成才删旧图」——这是为「编辑回滚」服务的关键技术改动。最后接通保存失败提示。

**Interfaces this task produces:**
- `EntryEditorViewModel.cancel()` —— 用户点取消时调用,封装分支(新建抹除 / 编辑回滚)
- `EntryEditorViewModel.lastSaveError: Error?` —— `save()` 抛错时填充,View 用 `.alert` 监听
- `EntryEditorViewModel.deferredImageDeletion: [String]` —— 内部缓存「编辑期间被移除但磁盘文件未删」的旧图文件名,正常保存成功后才清理;取消时不清理

### Part A: VM 改造(快照 + 延迟删图 + cancel + error)

- [ ] **Step 1: 在 VM 中加 EntrySnapshot 结构与字段**

打开 `dayfold/dayfold/ViewModels/EntryEditorViewModel.swift`,在 class 内(line 9 后)加私有结构与字段:

```swift
private struct EntrySnapshot {
    var title: String
    var content: String
    var mood: String
    var isFavorite: Bool
    var tags: [Tag]
    var mediaFilenames: [String]
    var placeName: String?
    var weatherTemperature: Double
    var weatherCondition: String
    var weatherIcon: String

    static func capture(from entry: Entry, selectedTags: [Tag]) -> EntrySnapshot {
        EntrySnapshot(
            title: entry.wrappedTitle,
            content: entry.wrappedContent,
            mood: entry.wrappedMood,
            isFavorite: entry.isFavorite,
            tags: selectedTags,
            mediaFilenames: entry.mediaAssetsArray.map { $0.wrappedFilename },
            placeName: entry.location?.wrappedPlaceName,
            weatherTemperature: entry.location?.weatherTemperature ?? 0,
            weatherCondition: entry.location?.weatherCondition ?? "",
            weatherIcon: entry.location?.weatherIcon ?? "sun.max.fill"
        )
    }
}
```

在 class 字段区(line 24-33 之后)加:

```swift
private var originalSnapshot: EntrySnapshot?
private var deferredOldFilenames: [String] = []
@Published var lastSaveError: Error?
```

注意:若 `wrappedFilename` 在 MediaAsset 扩展中不存在(自查),需使用 `($0.value(forKey: "filename") as? String) ?? ""` 或先在 Models/MediaAsset.swift 中添加(若缺,补一行 `var wrappedFilename: String { filename ?? "" }`)。

- [ ] **Step 2: 在 init 中填充 snapshot**

打开 `init(context:entry:prefillDate:notebook:)`(line 47-76),在 `if let entry = entry { ... loadExistingImages(from: entry) }` 块内、`} else {` 之前,**添加一行**快照捕获:

```swift
self.originalSnapshot = EntrySnapshot.capture(from: entry, selectedTags: entry.tagsArray)
```

不要在 `else` 分支(新建)里设 snapshot——新建没有原始态。

- [ ] **Step 3: 改 save() 中的图片处理为「延迟删除」**

打开 `save()` 方法(line 103-172),修改图片重建逻辑(line 147-166)。

原逻辑:**imagesChanged 时,先全量删除旧 MediaAsset 记录 + 磁盘文件,再保存新图**。

新逻辑:
1. 计算「将被替换的旧文件名」= 当前 `entryToSave.mediaAssetsArray` 的 filename 列表;
2. 把这些文件名加入 `deferredOldFilenames` (而不是立即删);
3. 删除旧 MediaAsset 记录(只解绑关系,**不删磁盘文件**);
4. 保存新图;
5. 保留 `imagesChanged = false` 与现有 MediaAsset 创建逻辑不动。

把 line 147-166 的:

```swift
if imagesChanged {
    // 删除旧的 MediaAsset 记录与磁盘文件
    for asset in entryToSave.mediaAssetsArray {
        let filename = asset.wrappedFilename
        viewContext.delete(asset)
        Task { await MediaService.shared.deleteImage(filename: filename) }
    }
    // 按当前 images 顺序重新保存
    for (index, image) in images.enumerated() {
        if let result = await MediaService.shared.saveImage(image) {
            let asset = MediaAsset.create(type: .photo, filename: result.filename, in: viewContext)
            asset.thumbnailData = result.thumbnail
            asset.order = Int32(index)
            asset.width = Int32(image.size.width)
            asset.height = Int32(image.size.height)
            asset.entry = entryToSave
        }
    }
    imagesChanged = false
}
```

替换为:

```swift
if imagesChanged {
    // 延迟删除:仅记录旧文件名,真正删除推迟到 save() 成功之后
    let oldFilenames = entryToSave.mediaAssetsArray.map { $0.wrappedFilename }
    deferredOldFilenames.append(contentsOf: oldFilenames)

    // 删除旧 MediaAsset 记录(关系自动解绑),不删磁盘文件
    for asset in entryToSave.mediaAssetsArray {
        viewContext.delete(asset)
    }
    // 按当前 images 顺序重新保存
    for (index, image) in images.enumerated() {
        if let result = await MediaService.shared.saveImage(image) {
            let asset = MediaAsset.create(type: .photo, filename: result.filename, in: viewContext)
            asset.thumbnailData = result.thumbnail
            asset.order = Int32(index)
            asset.width = Int32(image.size.width)
            asset.height = Int32(image.size.height)
            asset.entry = entryToSave
        }
    }
    imagesChanged = false
}
```

- [ ] **Step 4: 改 save() 错误处理 + 成功后清理 deferred 旧图**

把 line 168 的 `try? CoreDataStack.shared.save()` 替换为:

```swift
do {
    try CoreDataStack.shared.save()
} catch {
    lastSaveError = error
    isSaving = false
    return false
}

// 保存成功后,真正物理删除被替换的旧图文件
if !deferredOldFilenames.isEmpty {
    let toDelete = deferredOldFilenames
    deferredOldFilenames.removeAll()
    Task { await MediaService.shared.deleteImages(filenames: toDelete) }
}

isSaving = false
return true
```

注意:`MediaService.deleteImages(filenames:)` 当前可能不存在——自查 `dayfold/dayfold/Services/MediaService.swift`,若只有 `deleteImage(filename:)` 单文件版本,在该文件中加:

```swift
func deleteImages(filenames: [String]) async {
    for filename in filenames {
        await deleteImage(filename: filename)
    }
}
```

放在 `deleteImage(filename:)` 方法紧邻处即可,无需新文件。

- [ ] **Step 5: 在 VM 中加 cancel() 方法**

在 `save()` 方法之后(line 172 之后),加:

```swift
func cancel() async {
    autoSaveTimer?.invalidate()

    // 取消编辑:把 current VM 状态回滚到 snapshot 前的字段
    if let snapshot = originalSnapshot {
        guard let existing = entry else { return }
        existing.title = snapshot.title.isEmpty ? nil : snapshot.title
        existing.content = snapshot.content
        existing.mood = snapshot.mood.isEmpty ? nil : snapshot.mood
        existing.isFavorite = snapshot.isFavorite
        existing.tags = NSSet(array: snapshot.tags)
        existing.modifiedAt = Date()
        existing.needsSync = true

        // 还原 location/weather 字段
        if let location = existing.location {
            location.placeName = snapshot.placeName
            location.weatherTemperature = snapshot.weatherTemperature
            location.weatherCondition = snapshot.weatherCondition.isEmpty ? nil : snapshot.weatherCondition
            location.weatherIcon = snapshot.weatherIcon
        }

        // 还原图片:删除当前 MediaAsset 记录,按 snapshot 重建
        for asset in existing.mediaAssetsArray {
            viewContext.delete(asset)
        }
        for (index, filename) in snapshot.mediaFilenames.enumerated() {
            // 重新创建 MediaAsset 指向磁盘上未删除的旧文件
            let asset = MediaAsset(context: viewContext)
            asset.id = UUID()
            asset.typeRaw = MediaAssetType.photo.rawValue
            asset.filename = filename
            asset.order = Int32(index)
            asset.entry = existing
            asset.needsSync = true
            asset.createdAt = Date()
        }

        // 取消时不删 deferred 旧图(用户没点完成)
        deferredOldFilenames.removeAll()

        try? CoreDataStack.shared.save()
        return
    }

    // 新建日记:entry 已 auto-save 创建 → 物理删除(不进回收站)
    guard let draft = entry else { return }
    for asset in draft.mediaAssetsArray {
        let filename = asset.wrappedFilename
        viewContext.delete(asset)
        Task { await MediaService.shared.deleteImage(filename: filename) }
    }
    if let location = draft.location {
        viewContext.delete(location)
    }
    viewContext.delete(draft)
    deferredOldFilenames.removeAll()
    try? CoreDataStack.shared.save()
}
```

注意:
- `MediaAsset` 的字段名以生成的 NSManagedObject 为准——若 `typeRaw` / `needsSync` / `createdAt` 不存在,自查 Models/MediaAsset.swift 补齐或在 cancel() 内用 `asset.setValue(filename, forKey: "filename")` 兜底(尽量用类型安全属性)。
- `MediaAsset.create(type:filename:in:)` 工厂已存在(line 157 用过),优先使用它而非直接 `MediaAsset(context:)`:`MediaAsset.create(type: .photo, filename: filename, in: viewContext)`,再设置 `order` 与 `entry`。

修正版(更稳妥):

```swift
for (index, filename) in snapshot.mediaFilenames.enumerated() {
    let asset = MediaAsset.create(type: .photo, filename: filename, in: viewContext)
    asset.order = Int32(index)
    asset.entry = existing
}
```

- [ ] **Step 6: 在 deinit 中停掉 autoSaveTimer 已有**

`deinit` 已 line 99-101 存在,无需改。

### Part B: View 改造(取消按钮 + saveError 接通)

- [ ] **Step 7: 在 View 加 viewModel 字段引用(若需要)**

打开 `dayfold/dayfold/Views/Entry/EntryEditorView.swift`,确认 line 13 的 `@StateObject private var viewModel: EntryEditorViewModel` 已就绪。

- [ ] **Step 8: 修改 topBar,加取消按钮**

定位 `topBar` 计算属性(line 48-80),在 HStack 内的 `Spacer()` 之前(line 57),插入取消按钮:

```swift
Button("取消") {
    Task {
        await viewModel.cancel()
        dismiss()
    }
}
.font(.system(size: 16, weight: .regular))
.foregroundColor(editorSub)
.disabled(viewModel.isSaving)
```

这样 topBar 顺序:左 日期 → 中 取消 → 右 完成。

- [ ] **Step 9: 接通 showingSaveError,改为监听 viewModel.lastSaveError**

定位 line 16 的 `@State private var showingSaveError = false` 与 line 41-43 的 `.alert`。

把 line 16 改为:

```swift
// showingSaveError 由 viewModel.lastSaveError 驱动,无需本地状态
```

把 line 41-43 的 `.alert` 替换为(接 onChange 链式触发):

```swift
.alert("保存失败", isPresented: Binding(
    get: { viewModel.lastSaveError != nil },
    set: { if !$0 { viewModel.lastSaveError = nil } }
)) {
    Button("确定", role: .cancel) {}
} message: {
    Text(viewModel.lastSaveError?.localizedDescription ?? "请重试")
}
```

或者更 SwiftUI 习惯的写法:用 `.onChange(of: viewModel.lastSaveError)` 触发本地 @State,这里两种写法二选一,推荐 `.onChange` 版:

```swift
.onChange(of: viewModel.lastSaveError) { _, newValue in
    showingSaveError = newValue != nil
}
.alert("保存失败", isPresented: $showingSaveError) {
    Button("确定", role: .cancel) {
        viewModel.lastSaveError = nil
    }
} message: {
    Text(viewModel.lastSaveError?.localizedDescription ?? "请重试")
}
```

两种都行,选其一保持风格一致。

- [ ] **Step 10: 跑构建验证**

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -5
```

期望:`** BUILD SUCCEEDED **`。SourceKit 跨文件类型报错可忽略,以 xcodebuild 为准。

- [ ] **Step 11: 提交**

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/ViewModels/EntryEditorViewModel.swift \
        dayfold/dayfold/Views/Entry/EntryEditorView.swift \
        dayfold/dayfold/Services/MediaService.swift
git commit -m "feat: 编辑器取消按钮 + 图片延迟删除 + 保存失败提示"
```

### 验收点(task 结束时核对,CLI 环境无法模拟器交互,只跑代码路径)

| # | 验收项 | 代码路径核对 |
|---|--------|--------------|
| B3.1 | 取消新建(auto-save 已创建)→ 物理删除 Entry + MediaAsset 磁盘文件 + Location | `cancel()` line 「新建日记」分支 |
| B3.2 | 取消新建(auto-save 未创建)→ 直接 dismiss | `entry == nil` 时 `guard let draft = entry else { return }` 之后 `dismiss()` |
| B3.3 | 取消编辑 → title/content/mood/tags/isFavorite/location/weather 回滚 | `cancel()` 「编辑既有」分支,字段逐一赋值 |
| B3.4 | 取消编辑 → 图片回到原始状态 | `cancel()` 中 `for asset in existing.mediaAssetsArray { viewContext.delete(asset) }` + 按 `snapshot.mediaFilenames` 重建 MediaAsset,磁盘文件不动 |
| B3.5 | 正常完成保存 → 旧图物理清理 | `save()` 成功后的 `deleteImages(filenames: toDelete)` |
| B3.6 | 取消时 deferred 旧图不被清理 | `cancel()` 内 `deferredOldFilenames.removeAll()` 仅清空队列,不调用 `deleteImages` |
| B3.7 | 保存失败 → 弹 alert | `save()` `catch` 内 `lastSaveError = error` → View `.onChange` → `.alert` |

---

## Task B4: mood 心情输入

**Files:**
- Modify: `dayfold/dayfold/ViewModels/EntryEditorViewModel.swift` (加 mood 字段 + save 写入)
- Modify: `dayfold/dayfold/Views/Entry/EntryEditorView.swift` (metaBar 加 mood 控件)

**目的:** 用户决策:5 个 SF Symbol 一排点选,仅存名字字符串(`Entry.mood` schema 已支持)。

- [ ] **Step 1: 在 VM 加 mood 字段**

打开 `dayfold/dayfold/ViewModels/EntryEditorViewModel.swift`,在 `@Published` 字段区(line 10-22),`@Published var isFavorite = false` 之后加:

```swift
@Published var mood: String = ""
```

- [ ] **Step 2: 在 init 编辑既有日记分支填充 mood**

打开 `init`,在 `if let entry = entry { ... self.isFavorite = entry.isFavorite ... }` 块内(line 58 后),加:

```swift
self.mood = entry.wrappedMood
```

- [ ] **Step 3: 在 save() 写入 mood**

打开 `save()` 方法,在 line 125 附近的 `entryToSave.isFavorite = isFavorite` 之后,加:

```swift
entryToSave.mood = mood.isEmpty ? nil : mood
```

- [ ] **Step 4: 在 EntryEditorView 加 MoodSelector**

打开 `dayfold/dayfold/Views/Entry/EntryEditorView.swift`,在 `metaBar` 计算属性内(line 84-117),在 `Spacer()` 之前(line 112),插入:

```swift
MoodSelector(mood: $viewModel.mood)
```

然后在文件底部(私有扩展区之上,`#Preview` 之前),新增本地组件:

```swift
private struct MoodSelector: View {
    @Binding var mood: String
    private let options: [(symbol: String, value: String)] = [
        ("face.dashed", "blank"),
        ("cloud", "cloudy"),
        ("sun.max", "sunny"),
        ("moon.stars", "night"),
        ("sparkles", "sparkle")
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.value) { option in
                Button {
                    mood = (mood == option.value) ? "" : option.value
                } label: {
                    Image(systemName: option.symbol)
                        .font(.system(size: 14, weight: mood == option.value ? .semibold : .regular))
                        .foregroundColor(mood == option.value ? accentCyan : editorSub)
                        .frame(width: 24, height: 24)
                }
            }
        }
    }
}
```

注意:`accentCyan` 与 `editorSub` 已是文件顶部常量(line 9、line 7),直接引用。

- [ ] **Step 5: 跑构建验证**

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -5
```

期望:`** BUILD SUCCEEDED **`。

- [ ] **Step 6: 提交**

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/ViewModels/EntryEditorViewModel.swift \
        dayfold/dayfold/Views/Entry/EntryEditorView.swift
git commit -m "feat: 编辑器心情选择控件(5 个 SF Symbol)"
```

### 验收点

| # | 验收项 | 代码路径 |
|---|--------|----------|
| B4.1 | 新建日记选 mood → 写库 | `save()` 中 `entryToSave.mood = mood.isEmpty ? nil : mood` |
| B4.2 | 编辑既有日记 → mood 字段显示当前值 | `init` 中 `self.mood = entry.wrappedMood` |
| B4.3 | mood 控件可点选切换 | `MoodSelector` 内 `Button { mood = ... }` |
| B4.4 | 取消编辑 → mood 回滚到 snapshot.mood | `cancel()` 中 `existing.mood = snapshot.mood.isEmpty ? nil : snapshot.mood`(Task B3 已含) |

---

## 全局验收(全部 task 完成后核对)

阶段 B 设计稿第五节验收:「编辑器可用 Markdown 格式化、写日记时选标签、选心情;取消能真正放弃(新建抹除、编辑完整回滚含图片);保存失败有提示。」

| # | 验收项 | 对应 task |
|---|--------|-----------|
| B.1 | Markdown 格式化(7 个格式按钮) | B1 |
| B.2 | 写日记时可选标签 | B2 |
| B.3 | 可选心情(5 SF Symbol) | B4 |
| B.4 | 取消按钮(新建抹除草稿) | B3 |
| B.5 | 取消按钮(编辑完整回滚含图片) | B3 |
| B.6 | 保存失败有 alert 提示 | B3 |

---

## 自评(写完计划后核对)

**Spec coverage:** B1-B4 全部覆盖设计稿第 117-162 行。Task B3 把方案 b(取消语义)与图片延迟删除合并实现,符合设计稿决策 #5。Task B0 入库阶段 0 产物。mood 控件形式按用户决策用 5 个 SF Symbol。

**Placeholder scan:** 无 TBD/TODO/「待补」「类似 Task」。

**Type consistency:**
- `Entry.wrappedMood` 已在 Models/Entry.swift:14 存在
- `MediaAsset.wrappedFilename` 需自查,缺则补一行
- `MediaService.deleteImages(filenames:)` 需新增,Step 4 内含
- `MediaAsset.create(type:filename:in:)` 已在(line 157 引用过)

**Scope:** 阶段 B 一个计划,B1-B4 紧密耦合(B3 的快照/延迟删图同时支撑 cancel 语义),不拆为多个计划。

---

## 执行选项

**Plan complete and saved to `docs/superpowers/plans/2026-08-01-editor-wiring.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**