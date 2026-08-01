# 阶段 E++ · PDF / Markdown 导出 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) 或 superpowers:executing-plans task-by-task。本计划以 subagent-driven 模式写就——每个 task 一个 implementer subagent + spec/quality 双审 + 阶段 E++ 整分支宽审。Checkbox 用 `- [ ]`。

**Goal:** EntryDetailView Toolbar 加 Menu(三点),内含「导出 PDF」+「导出 Markdown」+「导出卡片图片(已有)」三选项;点击走系统分享面板(`UIActivityViewController`)。Markdown 走 Obsidian 风格 front-matter;PDF 走文本型 + 图片插入。

**Architecture:** 新建 `EntryPDFExporter` / `EntryMarkdownExporter` / `ExportShareSheet` 3 文件;改 `EntryDetailView.swift` Toolbar 加 Menu。**零 schema 改动、零新依赖、PDFKit + UIKit + UIActivityViewController 都是 iOS 系统框架**。

**Tech Stack:** SwiftUI + PDFKit + UIKit (`UIGraphicsPDFRenderer` / `UIActivityViewController`),沿用项目暖色 token。

## 全局约束(全阶段 E++ 不变)

- **commit message** 中文 Conventional Commits(`类型: 描述`);E++3 一个 commit。
- **构建命令**(从 `/Users/rich1e/workspace/code/dayfold/dayfold` 子目录跑):
  ```
  xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
  ```
  必须 `** BUILD SUCCEEDED **`。SourceKit CLI 误报忽略。
- **暖色 token 严格**:PDF 用 `UIColor(Color.warmDark)` / `UIColor(Color.warmBrown)` 间接;不引入新颜色。
- **导航容器**:本仓库全部用 `NavigationView`,不升级 NavigationStack。
- **不引入新依赖**:`PDFKit` / `UIKit` / `UIGraphicsPDFRenderer` / `UIActivityViewController` 都是 iOS 系统。
- **不改动 schema**:`dayfold.xcdatamodeld/` 零修改。
- **不自动 push**:留本地即可,详见 `~/.claude/projects/.../memory/feedback_no-auto-push.md`。
- **文件末尾必须有换行符**(`.swift` 文件标准)。
- **任何「状态变化触发视觉变化」的 modifier / 按钮必须自带 `.animation(...)`**(阶段 E+ 教训)。
- **本阶段 E++ 仅 1 个 task(E++3)**,因为 MVP 范围可控(3 文件 + 1 改),实施步骤内部推进。

---

## Task E++3:Entry PDF / Markdown 导出

**Files:**
- Create: `dayfold/dayfold/Services/EntryPDFExporter.swift`
- Create: `dayfold/dayfold/Services/EntryMarkdownExporter.swift`
- Create: `dayfold/dayfold/Views/Common/ExportShareSheet.swift`
- Modify: `dayfold/dayfold/Views/Entry/EntryDetailView.swift`(Toolbar 加 Menu + 新增 `@State pdfShareURL`/`mdShareURL` + 加两个 `.sheet(item:)`)

**Interfaces:**
- Consumes: `Entry.wrappedTitle / wrappedContent / wrappedMood / createdAt / modifiedAt / location / tagsArray / mediaAssetsArray`、`Location.wrappedPlaceName / weatherTemperature / wrappedCondition`、`MediaAsset.wrappedFilename`、`Color.warmDark / warmBrown`。
- Produces: Toolbar Menu 含「导出 PDF」+「导出 Markdown」+「导出卡片图片」;PDF/Markdown 文件走系统分享面板。

### Step 1:新建 EntryMarkdownExporter.swift

文件:`dayfold/dayfold/Services/EntryMarkdownExporter.swift`

```swift
// Services/EntryMarkdownExporter.swift
import Foundation

@MainActor
enum EntryMarkdownExporter {
    /// 将 entry 渲染为 Obsidian 风格 Markdown (front-matter + 正文 + 图片文件名)
    static func renderMarkdown(entry: Entry) -> String {
        var md = ""

        // front-matter (YAML)
        md += "---\n"
        let title = entry.wrappedTitle.isEmpty ? "Untitled" : entry.wrappedTitle
        md += "title: \(title)\n"
        if let date = entry.createdAt {
            md += "date: \(ISO8601DateFormatter().string(from: date))\n"
        }
        if let modified = entry.modifiedAt, modified != entry.createdAt {
            md += "modified: \(ISO8601DateFormatter().string(from: modified))\n"
        }
        if !entry.tagsArray.isEmpty {
            md += "tags: ["
            md += entry.tagsArray.map { $0.wrappedName }.joined(separator: ", ")
            md += "]\n"
        }
        if let loc = entry.location {
            md += "location: \(loc.wrappedPlaceName)\n"
        }
        if !entry.wrappedMood.isEmpty {
            md += "mood: \(entry.wrappedMood)\n"
        }
        md += "---\n\n"

        // 标题
        if !entry.wrappedTitle.isEmpty {
            md += "# \(entry.wrappedTitle)\n\n"
        }

        // 元信息行
        if let loc = entry.location {
            let parts: [String] = [
                loc.wrappedPlaceName,
                loc.weatherTemperature > 0 || loc.weatherTemperature < 0
                    ? "\(Int(loc.weatherTemperature))°C"
                    : "",
                loc.wrappedCondition
            ].filter { !$0.isEmpty }
            if !parts.isEmpty {
                md += "*\(parts.joined(separator: " · "))*\n\n"
            }
        }

        // 正文
        md += entry.wrappedContent
        if !entry.wrappedContent.isEmpty && !entry.wrappedContent.hasSuffix("\n") {
            md += "\n"
        }
        md += "\n"

        // 图片文件名列表(仅图片类型,过滤视频)
        let photoAssets = entry.mediaAssetsArray.filter { $0.type == .photo }
        if !photoAssets.isEmpty {
            md += "## 附件\n\n"
            for asset in photoAssets {
                md += "- ![](\(asset.wrappedFilename))\n"
            }
        }

        return md
    }

    /// 将 Markdown 写入临时目录,返回 URL
    static func writeTempFile(_ markdown: String, entry: Entry) -> URL? {
        let filename = filenameSlug(for: entry) + ".md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func filenameSlug(for entry: Entry) -> String {
        let base = entry.wrappedTitle.isEmpty ? "Untitled" : entry.wrappedTitle
        let slug = base
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "\n", with: "")
        let prefix = String(entry.id?.uuidString.prefix(8) ?? "entry")
        return "\(prefix)-\(slug)"
    }
}
```

### Step 2:新建 EntryPDFExporter.swift

文件:`dayfold/dayfold/Services/EntryPDFExporter.swift`

```swift
// Services/EntryPDFExporter.swift
import SwiftUI
import UIKit
import PDFKit

@MainActor
enum EntryPDFExporter {
    /// 将 entry 渲染为 PDF(文本型 + 图片插入),返回临时文件 URL;失败返回 nil
    static func renderPDF(entry: Entry, images: [UIImage]) -> URL? {
        let pageSize = CGSize(width: 595, height: 842)  // A4 72dpi
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let filename = filenameSlug(for: entry) + ".pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var y: CGFloat = margin
                let contentWidth = pageSize.width - 2 * margin

                // 标题
                if !entry.wrappedTitle.isEmpty {
                    let title = NSAttributedString(
                        string: entry.wrappedTitle,
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                            .foregroundColor: UIColor(Color.warmDark)
                        ]
                    )
                    title.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 40))
                    y += 48
                }

                // 元信息
                if let loc = entry.location {
                    let parts: [String] = [
                        loc.wrappedPlaceName,
                        loc.weatherTemperature > 0 || loc.weatherTemperature < 0
                            ? "\(Int(loc.weatherTemperature))°C"
                            : "",
                        loc.wrappedCondition
                    ].filter { !$0.isEmpty }
                    if !parts.isEmpty {
                        let meta = NSAttributedString(
                            string: parts.joined(separator: " · "),
                            attributes: [
                                .font: UIFont.systemFont(ofSize: 11),
                                .foregroundColor: UIColor(Color.warmBrown)
                            ]
                        )
                        meta.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 16))
                        y += 24
                    }
                }

                // 正文
                if !entry.wrappedContent.isEmpty {
                    let content = NSAttributedString(
                        string: entry.wrappedContent,
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 14),
                            .foregroundColor: UIColor(Color.warmDark),
                            .paragraphStyle: {
                                let ps = NSMutableParagraphStyle()
                                ps.lineSpacing = 4
                                return ps
                            }()
                        ]
                    )
                    let remainingHeight = pageSize.height - y - margin
                    let contentRect = CGRect(x: margin, y: y, width: contentWidth, height: remainingHeight)
                    content.draw(with: contentRect,
                                 options: [.usesLineFragmentOrigin, .usesFontLeading],
                                 context: nil)
                }

                // 图片(独立页)
                let photoImages = images  // EntryDetailView 已过滤为图片类型
                if !photoImages.isEmpty {
                    ctx.beginPage()
                    var imgY: CGFloat = margin
                    let imgMaxWidth = contentWidth
                    let imgMaxHeight = pageSize.height - 2 * margin
                    for image in photoImages {
                        let aspectRatio = image.size.height / max(image.size.width, 1)
                        let imgW = min(imgMaxWidth, image.size.width)
                        let imgH = imgW * aspectRatio
                        if imgY + imgH > imgMaxHeight {
                            ctx.beginPage()
                            imgY = margin
                        }
                        let imgRect = CGRect(x: (pageSize.width - imgW) / 2,
                                             y: imgY, width: imgW, height: imgH)
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

    private static func filenameSlug(for entry: Entry) -> String {
        let base = entry.wrappedTitle.isEmpty ? "Untitled" : entry.wrappedTitle
        let slug = base
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "\n", with: "")
        let prefix = String(entry.id?.uuidString.prefix(8) ?? "entry")
        return "\(prefix)-\(slug)"
    }
}
```

### Step 3:新建 ExportShareSheet.swift

文件:`dayfold/dayfold/Views/Common/ExportShareSheet.swift`

```swift
// Views/Common/ExportShareSheet.swift
import SwiftUI
import UIKit

/// UIViewControllerRepresentable 包裹 UIActivityViewController
/// 用于分享任意 items(URL / String / UIImage 等)
struct ExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

### Step 4:EntryDetailView Toolbar 加 Menu + share sheet

文件:`dayfold/dayfold/Views/Entry/EntryDetailView.swift`

在 `struct EntryDetailView` 顶部添加 `@State` 字段:

```swift
@State private var pdfShareURL: TempFileURL?
@State private var mdShareURL: TempFileURL?
@State private var exportError: String?
```

文件底部(EntryDetailView struct 外)添加 URL wrapper:

```swift
/// Identifiable wrapper for URL (用于 .sheet(item:))
struct TempFileURL: Identifiable {
    let url: URL
    var id: URL { url }
}
```

修改 ToolbarItem 内 HStack,在「编辑」按钮后加 Menu:

```swift
ToolbarItem(placement: .navigationBarTrailing) {
    HStack(spacing: 16) {
        // 既有:收藏 / 分享卡片 / 编辑
        Button { toggleFavorite() } label: {
            Image(systemName: entry.isFavorite ? "star.fill" : "star")
                .foregroundColor(.warmAccent)
        }
        Button { activeSheet = .card } label: {
            Image(systemName: "square.and.arrow.up.on.square")
                .foregroundColor(.warmAccent)
        }
        Button { activeSheet = .edit } label: {
            Text("编辑")
                .foregroundColor(.warmAccent)
        }
        // 新增:导出 Menu
        Menu {
            Button("导出 PDF", systemImage: "doc.richtext") {
                if let url = EntryPDFExporter.renderPDF(entry: entry, images: loadedImages) {
                    pdfShareURL = TempFileURL(url: url)
                } else {
                    exportError = "PDF 生成失败"
                }
            }
            Button("导出 Markdown", systemImage: "text.alignleft") {
                let md = EntryMarkdownExporter.renderMarkdown(entry: entry)
                if let url = EntryMarkdownExporter.writeTempFile(md, entry: entry) {
                    mdShareURL = TempFileURL(url: url)
                } else {
                    exportError = "Markdown 生成失败"
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.warmAccent)
        }
    }
}
```

在 EntryDetailView.body 末尾添加 share sheets:

```swift
.sheet(item: $pdfShareURL) { wrapped in
    ExportShareSheet(items: [wrapped.url])
}
.sheet(item: $mdShareURL) { wrapped in
    ExportShareSheet(items: [wrapped.url])
}
.alert("导出失败", isPresented: .constant(exportError != nil)) {
    Button("好") { exportError = nil }
} message: {
    Text(exportError ?? "")
}
```

### Step 5:构建 + 提交

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild ... build 2>&1 | tail -5
```
期望 `** BUILD SUCCEEDED **`。

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/Services/EntryPDFExporter.swift \
        dayfold/dayfold/Services/EntryMarkdownExporter.swift \
        dayfold/dayfold/Views/Common/ExportShareSheet.swift \
        dayfold/dayfold/Views/Entry/EntryDetailView.swift
git commit -m "feat(entry): Toolbar Menu 支持导出 PDF / Markdown"
```

### 验收点

| # | 项 | 核对路径 |
|---|-----|------|
| E++3.1 | Toolbar 出现三点 Menu,内含「导出 PDF」「导出 Markdown」 | EntryDetailView Toolbar Menu |
| E++3.2 | 导出 PDF 走系统分享面板 | ExportShareSheet 弹出 |
| E++3.3 | 导出 Markdown 走系统分享面板 | ExportShareSheet 弹出 |
| E++3.4 | Markdown 含 front-matter(title/date/tags)+ 标题 + 元信息 + 正文 + 图片文件名 | EntryMarkdownExporter.renderMarkdown |
| E++3.5 | PDF 含标题 + 元信息 + 正文 + 图片(若有) | EntryPDFExporter.renderPDF |
| E++3.6 | 无新依赖 | PDFKit / UIKit / UIActivityViewController 都是系统 |
| E++3.7 | 无 schema 改动 | `git diff` 不动 xcdatamodeld |
| E++3.8 | 暖色 token 严格 | PDF 用 UIColor(Color.warmDark / warmBrown) |
| E++3.9 | 空 Entry 不闪退 | 标题/正文/图片都可空,exporter 仍输出有效文件 |
| E++3.10 | xcodebuild BUILD SUCCEEDED | `cd dayfold && xcodebuild ... build 2>&1 \| tail -5` |

---

## Verification(阶段 E++ 完工后核对)

1. **构建**:`xcodebuild ... build` `** BUILD SUCCEEDED **`
2. **运行时**(必须人工跑模拟器,reviewer 无法验证):
   - 模拟器启动 → 打开任意一篇 Entry → Toolbar 出现三点 Menu
   - 点「导出 PDF」→ 系统分享面板弹出 → 选「存储到文件」/「AirDrop」验证文件能打开
   - 点「导出 Markdown」→ 系统分享面板弹出 → 选「存储到文件」/「AirDrop」 → 文件用文本编辑器打开,front-matter + 正文正确
   - 标题/正文/图片各种组合(全空 / 仅标题 / 仅正文 / 全填)验证边界
3. **回归**:阶段 A/B/C/D/E/E+ 全部功能仍正常工作
4. **schema 验证**:`git diff origin/main -- dayfold.xcdatamodeld/` 应为空
5. **阶段 E++ 整体目标**:设计文档「外部迁移与归档」验收 — Markdown 可迁出到 Obsidian;PDF 可归档/打印

## ⚠️ Cannot Verify From Diff(reviewer 必标)

- E++3.2 / E++3.3 / E++3.4 / E++3.5 中真实分享面板 / 文件内容验证,只能从代码层面验证逻辑正确性
- PDF 在 iOS 不同打印尺寸下的渲染表现
- Markdown 文件名 slug 在非 ASCII 标题下的兼容性