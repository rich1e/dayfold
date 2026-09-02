# Dayfold HANDOFF — 阶段 H · 图文混排改造（2026-09-02）

## 1. 当前任务目标与验收标准

**阶段 H 全部完成**：日记编辑与展示从「正文区 + 底部独立图片流（且最小撑高 320pt 导致大片空白）」改造为对标 Day One / Apple Notes 的 **图文混排（Inline Rich Text）**，并解决图文混排架构下的 view updates 死循环与选择器卡死问题。

| 模块 | 文件 | 改动内容 |
|------|------|----------|
| 富文本转换器 | `RichTextMarkdownParser.swift` (新增) | 实现 `ImageTextAttachment` 自适应等比缩放，区分文本/附件段落样式（紧凑 attachment 行：lineSpacing/paragraphSpacing=0、lineHeightMultiple=1.0），并吸收图片后紧随的换行符走紧凑样式，消除附件上下大段空白 |
| 富文本编辑器 | `SelectableTextEditor.swift` | 接入 `RichTextMarkdownParser`，支持内联附件渲染；新增 `isUpdatingFromSwiftUI` 重入守卫消除 view update 周期内反向回写；`onSelectionChange` / `onHeightChange` 改为异步派发；`textViewDidChange` 增加 `markdown != parent.text` 短路 |
| 编辑 ViewModel | `EntryEditorViewModel.swift` | 维护 `imagesMap: [String: UIImage]`，持久化保存时同步正文出现的图片顺序与持久化文件名替换，支持取消回滚 |
| 编辑主视图 | `EntryEditorView.swift` | 移除独立的 `imageFlow` VStack，消除多余空白占位，文字可在图片前后任意位置自由穿插编辑 |
| 详情与导出 | `EntryDetailView.swift` / `EntryMarkdownExporter.swift` | 详情页支持图文混排流展示，Markdown 导出原生支持内联图片且文末附件自动去重 |
| 选图器时序 | `PhotoLibraryPickerView.swift` | `finish()` 在 `await loadPickedPhotos` 后切回主线程再 `dismiss()` + `onDone()`，避免后台线程驱动 UIKit dismiss 卡死 |

**验收**：
- `xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build` 编译成功（`** BUILD SUCCEEDED **`）。
- 模拟器应用成功启动运行（PID 存活）。

## 2. 已读/已改的文件路径

- 新增：`dayfold/dayfold/Services/RichTextMarkdownParser.swift`
- 改：`dayfold/dayfold/Views/Entry/Components/SelectableTextEditor.swift`
- 改：`dayfold/dayfold/ViewModels/EntryEditorViewModel.swift`
- 改：`dayfold/dayfold/Views/Entry/EntryEditorView.swift`
- 改：`dayfold/dayfold/Views/Entry/EntryDetailView.swift`
- 改：`dayfold/dayfold/Services/EntryMarkdownExporter.swift`
- 改：`dayfold/dayfold/Views/Entry/Components/PhotoLibraryPickerView.swift`

## 3. 测试结果与构建状态

- 构建结果：`** BUILD SUCCEEDED **`
- 模拟器启动结果：成功启动 `com.Yuqi.dayfold`

## 4. 手工验证清单（供用户在模拟器复测）

1. **文字与图片上下间距**：在新建或编辑日记时输入一两行文字并插入图片，确认图片紧贴文字下方，不再有多余的大片空白。
2. **图片前后连续编辑**：在图片下方点击，光标正常落在换行后，输入文字能够正常穿插排列。
3. **删除图片**：点击图片后按键盘退格键（Backspace），确认图片能被直接删除。
4. **保存与详情展示**：点击右上角「完毕」保存，在日记详情页中确认图文按照插入顺序正确混排渲染。
5. **Markdown 导出**：在详情页菜单中选择「导出 Markdown」，确认导出的文档中图片标记位置与正文一致且无重复。
6. **循环报错与卡死**：选图后确认不再触发 `Publishing changes from within view updates is not allowed`，照片选择器点击「完成」后能正常 dismiss 并回到编辑器。

## 5. 关键修复细节（循环死锁 & 卡死）

### 根因
1. `SelectableTextEditor.updateUIView` 重新生成 `attributedText` 时同步触发 `textViewDidChange` → 回写 `@Binding text` → SwiftUI 在 view update 中又发布变更 → 死循环。
2. `reportHeight` 在 updateUIView 中同步调用 `onHeightChange` 写入外层 `@State textHeight`，同样会在 view update 周期触发渲染。
3. `PhotoLibraryPickerView.finish()` 中 `await loadPickedPhotos` 可能在非主线程返回，下游 `dismiss()` 在后台线程触发，UIKit dismiss 卡死。

### 修复
- `Coordinator` 新增 `isUpdatingFromSwiftUI: Bool`，`updateUIView` 重排 attributedText 前后置位，delegate 在该标志位为 true 时跳过回写。
- `textViewDidChange` 比较 `markdown != parent.text`，序列化结果未变时不写回。
- `textViewDidChangeSelection` 与 `reportHeight` 改为 `DispatchQueue.main.async` 派发，且仅在值变化时（`cachedSelectionLength` / `cachedHeight` 阈值）触发，避免重复 @State 写入。
- `finish()` 用 `await MainActor.run { ... }` 包裹 dismiss 与 onDone，确保 UIKit 调用在主线程。

## 6. 图片附件上下大段空白修复

### 根因
`RichTextMarkdownParser` 早期版本所有字符统一用 lineSpacing=4 的文本段落样式。NSTextAttachment 自身占据图片高度，但附件所在行的换行符仍走文本段落样式 + 字体 lineHeight（~30pt for body），导致图片后明显下沉一整行 line height。`attachmentBounds` 返回的 `y = 0` 也使图片顶端没有与上一行文字基线贴齐。

### 修复
- 新增 `makeAttachmentParagraphStyle()`：lineSpacing/paragraphSpacing/paragraphSpacingBefore 全为 0、lineHeightMultiple=1.0，紧凑附件行。
- 解析循环在追加 attachment 字符后探测紧随的 `\n`，将 `\n` 也归入 attachment 段（紧贴图片），再统一覆盖该段属性。
- 文本段落仍保留 4pt lineSpacing 提升正文可读性，仅图片所在行收紧。

## 7. 图片撑爆整屏 + 重开图片降级为 Markdown 原文

### 根因
1. **图片撑爆**：`ImageTextAttachment.attachmentBounds` 在 `isScrollEnabled=false` 的 UITextView 下 `lineFrag.width` 经常返回 0，fallback `UIScreen.main.bounds.width - 32 ≈ 343` 远小于原图 4032px 长边，scale 算成 1/12 仍撑出 4800pt 高度，撑爆 ScrollView。
2. **重开图片丢失**：`addPickedPhotos` 旧实现把图片写入 `imagesMap` 时使用 `UUID().uuidString` 作为 temp filename，并 append `![](temp)` 到 content；auto-save 路径不重建 MediaAsset 与持久化文件名，导致 Core Data 里保存的是 temp filename，图片物理文件根本没写入；下次打开 `loadExistingImages` 用 temp filename 查 MediaService 找不到 → `imagesMap[temp] = nil` → 富文本解析降级为 markdown 原文。

### 修复
- `attachmentBounds` 优先用 `textContainer.size.width` 兜底（UITextView 已正确设置该值），并限制最大高度为 `availableWidth * 1.8`，防极长竖图撑爆。
- `EntryEditorViewModel.addPickedPhotos` 改为先 `await MediaService.shared.saveImage(image)` 拿到真实 filename，再插入 `imagesMap` 与 `![](realFilename)`；删除 save 中的 temp 替换逻辑。
- 新增 `pendingSaveTasks: [Task<Void, Never>]` 跟踪在途持久化，`save()` 入口先 `await task.value` 全部任务，杜绝 race 导致 temp 漏写。
- `save()` 中图片重建改为按正文顺序 reconcile MediaAsset（保留现有、更新顺序、删除残留），由 `MediaService.shared.generateThumbnail(from:)` 生成缩略图。

## 8. 图片完全不显示（Image #8）终极修复 — 走对 UIKit 渲染路径

### 根因（多次返工后定位）
连续 4 轮反复改 `attachmentBounds` 高度上限、`image(forBounds:)` 现绘等都是**走错路径**。NSTextAttachment 渲染真相：

1. UIKit 渲染 attachment **优先用 `self.image`**（带解码缓存、异步解码、性能最佳）
2. 只有 `self.image == nil` 才 fallback 到 `image(forBounds:textContainer:characterIndex:)`
3. **`image(forBounds:)` 返回 nil 不崩溃，但 UIKit 直接放弃绘制**
4. 在 `image(forBounds:)` 里现绘 4032×3024 原图到目标尺寸会生成 ~30MB 中间位图，触发 iOS 内存压力 → **静默失败（图片不显示）**

之前几轮用 `image(forBounds:)` 现绘 + `self.image == nil` 的组合，**两条路径同时失败**：imageBounds 偶发为 0 时 guard 返回 nil → UIKit 放弃绘制；正常路径又现绘大位图触发内存压力。

### 修复方案
**`ImageTextAttachment` 在 init 期立即按 `containerWidth` 等比预渲染图片到 `self.image`，attachmentBounds 直接返回该尺寸**。这是 petehare.com、RichTextKit、canopas/rich-editor-swiftui 等成熟实现的共识做法。

### 实施细节
- `RichTextMarkdownParser.swift`：`ImageTextAttachment.init(image:filename:containerWidth:)` 立即用 `UIGraphicsImageRenderer` 预渲染到 `displaySize`，把结果赋给 `self.image`；`attachmentBounds` 直接返回 `displaySize`；**不再 override** `image(forBounds:)`，让 UIKit 走 `self.image` 标准路径。`attributedString` API 新增 `containerWidth` 参数透传给 attachment。
- `SelectableTextEditor.swift`：
  - 自定义 `EditorTextView: UITextView`，override `layoutSubviews` 在 bounds.width 真实就绪时触发 Coordinator 构建 attributedText（首次 make 时 `tv.bounds.width == 0`，不应立即构建，否则图片用兜底宽度预渲染后真实宽度变化时无法自适应）。
  - Coordinator 用 `cachedText` + `cachedImagesCount` + `cachedImagesKeys` + `lastUsedContainerWidth` 多维度比对决定是否重建。
  - 保留 `isUpdatingFromSwiftUI` 重入守卫、`async onHeightChange/onSelectionChange` 派发、`markdown != parent.text` 短路等所有防环逻辑（这些已验证有效）。

### 第三方库评估（已与用户确认不引入）
- `gonzalezreal/swift-markdown-ui`：纯只读渲染，不支持编辑器
- `LiYanan2004/MarkdownView`：纯只读渲染，不支持编辑器
- `danielsaidi/RichTextKit`：底层仍是 NSTextAttachment，且有 **Backspace 删图已知 bug（Issue #1494）**、作者因 iOS 26 SwiftUI 新 API 考虑停止维护
- `fatbobman` 文章的 RichText 方案（Platform Text View + SwiftUI View overlay）可行但工作量大，与"最小修图片不显示"目标不符
