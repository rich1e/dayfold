// Views/Entry/EntryDetailView.swift
import SwiftUI

struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let entry: Entry
    @State private var showingEditSheet = false
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
                        showingEditSheet = true
                    } label: {
                        Text("编辑")
                            .foregroundColor(.warmAccent)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EntryEditorView(
                entry: entry,
                context: entry.managedObjectContext ?? CoreDataStack.shared.viewContext
            )
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
