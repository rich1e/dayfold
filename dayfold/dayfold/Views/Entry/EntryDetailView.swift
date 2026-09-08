// Views/Entry/EntryDetailView.swift
import SwiftUI

private enum DetailSheet: Identifiable {
    case edit, card
    var id: Int { hashValue }
}

struct EntryDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var entry: Entry
    @State private var activeSheet: DetailSheet?
    @State private var loadedImagesMap: [String: UIImage] = [:]
    @State private var pdfShareURL: TempFileURL?
    @State private var mdShareURL: TempFileURL?
    @State private var exportError: String?

    var loadedImages: [UIImage] {
        entry.mediaAssetsArray.compactMap { loadedImagesMap[$0.wrappedFilename] }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.warmTitle)
                        .foregroundColor(theme.textPrimary)
                }

                // 头部信息
                EntryHeader(entry: entry)

                Divider()

                // 图文混排内容流
                entryContentFlow
            }
            .padding()
        }
        .background(theme.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: entry.isFavorite ? "star.fill" : "star")
                            .foregroundColor(theme.accentPrimary)
                    }
                    Button {
                        activeSheet = .card
                    } label: {
                        Image(systemName: "square.and.arrow.up.on.square")
                            .foregroundColor(theme.accentPrimary)
                    }
                    Button {
                        activeSheet = .edit
                    } label: {
                        Text("编辑")
                            .foregroundColor(theme.accentPrimary)
                    }
                    // 导出 Menu
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
                            .foregroundColor(theme.accentPrimary)
                    }
                }
            }
        }
        .sheet(item: $activeSheet, onDismiss: {
            Task { await loadImages() }
        }) { sheet in
            switch sheet {
            case .edit:
                EntryEditorView(
                    entry: entry,
                    context: entry.managedObjectContext ?? CoreDataStack.shared.viewContext
                )
            case .card:
                EntryCardPreviewSheet(entry: entry, images: loadedImages)
            }
        }
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
        .task {
            await loadImages()
        }
    }

    // MARK: - 图文混排展示

    private var entryContentFlow: some View {
        var segments = RichTextMarkdownParser.contentSegments(from: entry.wrappedContent)

        // 兜底：正文没有任何 ![] 标记但存在关联图片资产，文末渲染图片（详情页独有语义）
        let hasImageSegment = segments.contains { if case .image = $0 { return true } else { return false } }
        if !hasImageSegment && !loadedImages.isEmpty {
            for asset in entry.mediaAssetsArray {
                segments.append(.image(asset.wrappedFilename))
            }
        }

        return VStack(alignment: .leading, spacing: 12) {
            ForEach(segments.indices, id: \.self) { idx in
                switch segments[idx] {
                case .text(let str):
                    if !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(str)
                            .font(.warmBody)
                            .foregroundColor(theme.textPrimary)
                            .textSelection(.enabled)
                    }
                case .image(let filename):
                    if let image = loadedImagesMap[filename] {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(
                                image.size.width > 0 ? image.size.width / image.size.height : 1,
                                contentMode: .fit
                            )
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func toggleFavorite() {
        let context = entry.managedObjectContext ?? CoreDataStack.shared.viewContext
        entry.isFavorite.toggle()
        try? context.save()
    }

    private func loadImages() async {
        var map: [String: UIImage] = [:]
        for asset in entry.mediaAssetsArray {
            let filename = asset.wrappedFilename
            if let image = await MediaService.shared.loadImage(filename: filename) {
                map[filename] = image
            }
        }
        loadedImagesMap = map
    }
}

/// Identifiable wrapper for URL (用于 .sheet(item:))
struct TempFileURL: Identifiable {
    let url: URL
    var id: URL { url }
}
