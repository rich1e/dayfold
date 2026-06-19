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
