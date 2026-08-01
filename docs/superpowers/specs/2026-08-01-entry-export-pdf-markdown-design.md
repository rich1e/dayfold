# 阶段 E++ · PDF / Markdown 导出 设计文档

> 生成日期:2026-08-01
> 背景:阶段 0+A+B+C+D+E+E+ 全部完成,main HEAD `56da4bb`,领先 origin/main 35 commits(未推)。本轮做 `2026-04-07-...-design.md §2.2 v1.1` 指引的「导出为 PDF/Markdown」MVP,完善已有 `CardExporter`(当前只有卡片图片 + 保存到相册,无文本导出)。
> 依据:`dayfold/dayfold/Services/CardExporter.swift` 源码实测 —— 当前只有 `render(_:)` + `saveToPhotos(_:)`;`dayfold/dayfold/Views/Entry/EntryDetailView.swift:46-68` Toolbar 已用 3 按钮(收藏 / 分享卡片 / 编辑),可加 Menu 拓展。

## 一、目标与范围

让用户从 EntryDetailView 一键导出当前 Entry 为 PDF 或 Markdown 文件,通过 iOS 系统分享面板(`UIActivityViewController`)发到任意目标(Files / AirDrop / 其他 App)。Markdown 走 Obsidian 风格 front-matter,适配外部知识库迁移;PDF 走文本型 + 图片插入,适合归档与打印。

| # | 缺口 | 现状 | 阶段 |
|---|------|------|------|
| 1 | EntryDetailView 无 PDF 导出 | CardExporter 只有卡片图片渲染 | E++3 |
| 2 | EntryDetailView 无 Markdown 导出 | 完全无 | E++3 |

## 二、关键决策(已与用户确认)

1. **入口:EntryDetailView Toolbar 加 Menu(三点),含「导出 PDF」+「导出 Markdown」+「导出卡片图片(已有)」三选项**
2. **Markdown 格式:Obsidian 风格** —— front-matter YAML(`title` / `date` / `tags`)+ 正文 + 图片文件名列表(不复制图片二进制)
3. **PDF 样式:文本型 + 图片插入** —— 标题 + 元信息 + 正文 + 图片依序插入(图片走 `UIImage` 直接画到 PDF page,不做卡片样式)
4. **触发:点击选项 → 弹出系统分享面板(`UIActivityViewController`)**,用户选目标 App(Files 保存 / AirDrop / 其他)
5. **MVP 范围,不做**:
   - 批量导出(整本笔记本 / 全库)
   - 加密 PDF / 密码保护
   - 自定义字体 / 模板
   - 国际化(只走 zh-Hans / en)
   - 导出时自定义封面图(沿用 entry 内已有图片)
   - Markdown 双向同步(只导出,不做导入)
6. **零 schema 改动** —— 仅读 `Entry.createdAt / wrappedTitle / wrappedContent / location / tagsArray / mediaAssetsArray`。
7. **零新依赖** —— `PDFKit` + `UIKit` + `UIGraphicsPDFRenderer` + `UIActivityViewController` 都是 iOS 系统框架。
8. **不引入新颜色** —— 沿用暖色 token。

## 三、架构与数据流

```
EntryDetailView (Toolbar 右上 Menu)
└── Menu("ellipsis.circle")
    ├── Button("导出 PDF") → EntryPDFExporter.render(entry, images) → URL → ShareSheet
    ├── Button("导出 Markdown") → EntryMarkdownExporter.render(entry) → String → .md file → ShareSheet
    └── Button("导出卡片图片") → 既有 CardExporter(沿用)

ExportShareSheet (新建小工具)
└── UIViewControllerRepresentable 包裹 UIActivityViewController
    用于分享任意 URL 或 String
```

**新建文件**:
- `dayfold/dayfold/Services/EntryPDFExporter.swift` —— `EntryPDFExporter.renderPDF(entry:images:) -> URL`(写入 temp,返回 PDF 文件 URL)
- `dayfold/dayfold/Services/EntryMarkdownExporter.swift` —— `EntryMarkdownExporter.renderMarkdown(entry:) -> String`
- `dayfold/dayfold/Views/Common/ExportShareSheet.swift` —— UIViewControllerRepresentable 包裹 UIActivityViewController

**修改文件**:
- `dayfold/dayfold/Views/Entry/EntryDetailView.swift`(Toolbar 加 Menu + 两个新按钮)
- `dayfold/dayfold/Views/Entry/EntryCardPreviewSheet.swift`(若有"导出 PDF"按钮需求可加,MVP 不动)

## 四、核心算法

### 4.1 Markdown 导出(EntryMarkdownExporter)

```swift
@MainActor
enum EntryMarkdownExporter {
    static func renderMarkdown(entry: Entry) -> String {
        var md = ""
        // front-matter (YAML)
        md += "---\n"
        md += "title: \(entry.wrappedTitle.isEmpty ? "Untitled" : entry.wrappedTitle)\n"
        if let date = entry.createdAt {
            md += "date: \(ISO8601DateFormatter().string(from: date))\n"
        }
        if let date = entry.modifiedAt {
            md += "modified: \(ISO8601DateFormatter().string(from: date))\n"
        }
        if !entry.tagsArray.isEmpty {
            md += "tags: ["
            md += entry.tagsArray.map { $0.wrappedName }.joined(separator: ", ")
            md += "]\n"
        }
        md += "---\n\n"
        // 标题
        if !entry.wrappedTitle.isEmpty {
            md += "# \(entry.wrappedTitle)\n\n"
        }
        // 元信息
        if let loc = entry.location {
            md += "*\(loc.wrappedPlaceName)"
            if loc.weatherTemperature > 0 || !loc.wrappedCondition.isEmpty {
                md += " · \(Int(loc.weatherTemperature))°C · \(loc.wrappedCondition)"
            }
            md += "*\n\n"
        }
        // 正文
        md += entry.wrappedContent
        md += "\n\n"
        // 图片文件名列表
        let assets = entry.mediaAssetsArray
        if !assets.isEmpty {
            md += "## 附件\n\n"
            for asset in assets {
                md += "- ![](\(asset.wrappedFilename))\n"
            }
        }
        return md
    }
}
```

**写入文件**:`FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).md")`,filename = `entry-id 前 8 位 + 标题 slug`。

### 4.2 PDF 导出(EntryPDFExporter)

```swift
@MainActor
enum EntryPDFExporter {
    /// 将 entry 渲染为 PDF,返回临时文件 URL
    static func renderPDF(entry: Entry, images: [UIImage]) -> URL? {
        let pageSize = CGSize(width: 595, height: 842)  // A4 at 72dpi
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let filename = "Dayfold-\(filenameSlug(entry))-\(timestamp()).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var y: CGFloat = margin

                // 标题
                if !entry.wrappedTitle.isEmpty {
                    let title = NSAttributedString(
                        string: entry.wrappedTitle,
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                            .foregroundColor: UIColor(Color.warmDark)
                        ]
                    )
                    title.draw(in: CGRect(x: margin, y: y, width: pageSize.width - 2 * margin, height: 36))
                    y += 48
                }

                // 元信息
                if let loc = entry.location {
                    let meta = NSAttributedString(
                        string: "\(loc.wrappedPlaceName) · \(Int(loc.weatherTemperature))°C · \(loc.wrappedCondition)",
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 12),
                            .foregroundColor: UIColor(Color.warmBrown)
                        ]
                    )
                    meta.draw(in: CGRect(x: margin, y: y, width: pageSize.width - 2 * margin, height: 18))
                    y += 28
                }

                // 正文(简单换行)
                let content = NSAttributedString(
                    string: entry.wrappedContent,
                    attributes: [
                        .font: UIFont.systemFont(ofSize: 14),
                        .foregroundColor: UIColor(Color.warmDark)
                    ]
                )
                let contentRect = CGRect(x: margin, y: y,
                                         width: pageSize.width - 2 * margin,
                                         height: pageSize.height - y - margin)
                content.draw(with: contentRect,
                             options: [.usesLineFragmentOrigin, .usesFontLeading],
                             context: nil)

                // 图片(若有)
                if !images.isEmpty {
                    ctx.beginPage()  // 图片独立页
                    var imgY: CGFloat = margin
                    let imgMaxWidth = pageSize.width - 2 * margin
                    let imgMaxHeight = pageSize.height - 2 * margin
                    for image in images {
                        let imgW = min(imgMaxWidth, image.size.width * 0.5)
                        let imgH = imgW * (image.size.height / image.size.width)
                        if imgY + imgH > imgMaxHeight {
                            ctx.beginPage()
                            imgY = margin
                        }
                        let imgRect = CGRect(x: (pageSize.width - imgW) / 2, y: imgY, width: imgW, height: imgH)
                        image.draw(in: imgRect)
                        imgY += imgH + 12
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }
}
```

### 4.3 分享面板(ExportShareSheet)

```swift
struct ExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

### 4.4 跨边界

- 空 Entry(无标题无内容):仍生成 PDF / Markdown,front-matter 仅 UUID;PDF 空白但有效
- 图片为视频类型(`.video`):MVP 不导出视频(只导出图片);`mediaAssetsArray` 过滤 `type == .photo`
- 跨时区:`date` 字段用 `ISO8601DateFormatter` 无时区标记(UTC),Obsidian 默认解析 OK
- 大图片:PDF 缩小到 maxWidth,内存安全;Markdown 只列文件名

## 五、UI 与交互规范

### 5.1 Toolbar Menu

```swift
ToolbarItem(placement: .navigationBarTrailing) {
    HStack(spacing: 16) {
        Button { toggleFavorite() } label: { Image(systemName: "star") }
        Button { activeSheet = .card } label: { Image(systemName: "square.and.arrow.up.on.square") }
        Button { activeSheet = .edit } label: { Text("编辑") }
        Menu {
            Button("导出 PDF", systemImage: "doc.richtext") {
                if let url = EntryPDFExporter.renderPDF(entry: entry, images: loadedImages) {
                    pdfShareURL = url
                }
            }
            Button("导出 Markdown", systemImage: "text.alignleft") {
                let md = EntryMarkdownExporter.renderMarkdown(entry: entry)
                let url = writeMarkdown(md, entry: entry)
                mdShareURL = url
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.warmAccent)
        }
    }
}
.sheet(item: $pdfShareURL) { url in
    ExportShareSheet(items: [url])
}
```

### 5.2 触发反馈

- 导出按钮点击立即调用 exporter
- 失败时(写文件失败):`lastExportError = error` → 弹 alert
- 成功:share sheet 自动弹出
- **EntryDetailView 新增 `@State` 字段**(toolbar 触发器):
  - `@State private var pdfShareURL: URL?` —— `.sheet(item:)` 触发 PDF 分享
  - `@State private var mdShareURL: URL?` —— `.sheet(item:)` 触发 Markdown 分享
  - `URL` 须 `Identifiable` 扩展(id 用 `self`)或用单独 wrapper

## 六、验收标准

| # | 项 | 核对路径 |
|---|-----|------|
| E++3.1 | Toolbar 出现三点 Menu,内含「导出 PDF」「导出 Markdown」 | EntryDetailView Toolbar Menu |
| E++3.2 | 导出 PDF 走系统分享面板 | ExportShareSheet 弹出 |
| E++3.3 | 导出 Markdown 走系统分享面板 | ExportShareSheet 弹出 |
| E++3.4 | Markdown 含 front-matter(title/date/tags)+ 标题 + 元信息 + 正文 + 图片文件名 | EntryMarkdownExporter.renderMarkdown |
| E++3.5 | PDF 含标题 + 元信息 + 正文 + 图片(若有) | EntryPDFExporter.renderPDF |
| E++3.6 | 无新依赖 | PDFKit / UIKit / UIActivityViewController 都是系统 |
| E++3.7 | 无 schema 改动 | git diff xcdatamodeld 为空 |
| E++3.8 | 暖色 token 严格 | PDF 用 UIColor(Color.warmDark) / UIColor(Color.warmBrown) |
| E++3.9 | 空 Entry 不闪退 | 标题/正文/图片都可空,exporter 仍输出有效文件 |
| E++3.10 | xcodebuild BUILD SUCCEEDED | `cd dayfold && xcodebuild ... build 2>&1 \| tail -5` |

## 七、不做(明确延后)

1. 批量导出(整本 / 全库)
2. 加密 PDF / 密码保护
3. Markdown 导入 / 双向同步
4. 自定义字体 / 模板
5. 国际化(只 zh-Hans / en,MVP 不做多语言适配)
6. PDF 表格 / 列布局
7. 视频附件导出(MVP 仅图片)

## 八、风险

- **零架构风险**:不动 schema、不动 Service 主链路、不动 Navigator 容器
- **唯一浮点**:`UIGraphicsPDFRenderer` 的 PDF 尺寸与 iOS 系统打印尺寸的兼容性(MVP 用 A4 72dpi)
- **图片内存**:大图片(>10MB)在 PDF 渲染时可能 peak memory,需 `.aspectRatio` 等比缩放 + 分页
- **Markdown 编码**:文件名 slug 需 UTF-8 转 ASCII(MVP 简单替换 + fallback),Obsidian 默认解码

## 九、⚠️ 必须运行时验证(不可仅靠代码 review)

本轮验收的 **E++3.2 / E++3.3** 依赖模拟器跑起来看实际分享面板弹出,reviewer 仅能从 diff 验证:
- 代码能编译(BUILD SUCCEEDED)
- Exporter 数学/编码正确
- ShareSheet 包装正确

真正的「分享面板能否弹出 + 接收方 App 是否能正确打开 PDF / .md」需要在模拟器手动验证 → 用户验收。