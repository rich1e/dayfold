// Views/Entry/EntryDetailView.swift
import SwiftUI

private enum DetailSheet: Identifiable {
    case edit, card
    var id: Int { hashValue }
}

struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var entry: Entry
    @State private var activeSheet: DetailSheet?
    @State private var loadedImages: [UIImage] = []
    @State private var pdfShareURL: TempFileURL?
    @State private var mdShareURL: TempFileURL?
    @State private var exportError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.warmTitle)
                        .foregroundColor(.warmDark)
                }

                // 头部信息
                EntryHeader(entry: entry)

                Divider()

                // 内容 (纯文本渲染，后续可替换为 MarkdownUI)
                Text(entry.wrappedContent)
                    .font(.warmBody)
                    .foregroundColor(.warmDark)
                    .textSelection(.enabled)

                // 媒体网格
                if !loadedImages.isEmpty {
                    Divider()
                    MediaGrid(images: loadedImages, onRemove: nil)
                }
            }
            .padding()
        }
        .background(Color.warmPaper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: entry.isFavorite ? "star.fill" : "star")
                            .foregroundColor(.warmAccent)
                    }
                    Button {
                        activeSheet = .card
                    } label: {
                        Image(systemName: "square.and.arrow.up.on.square")
                            .foregroundColor(.warmAccent)
                    }
                    Button {
                        activeSheet = .edit
                    } label: {
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

    private func toggleFavorite() {
        let context = entry.managedObjectContext ?? CoreDataStack.shared.viewContext
        entry.isFavorite.toggle()
        try? context.save()
    }

    private func loadImages() async {
        var images: [UIImage] = []
        for asset in entry.mediaAssetsArray {
            if let image = await MediaService.shared.loadImage(filename: asset.wrappedFilename) {
                images.append(image)
            }
        }
        loadedImages = images
    }
}

/// Identifiable wrapper for URL (用于 .sheet(item:))
struct TempFileURL: Identifiable {
    let url: URL
    var id: URL { url }
}
