// Views/Entry/EntryListView.swift
import SwiftUI
import CoreData

struct EntryListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: EntryListViewModel
    @State private var showingNewEntry = false

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)],
        animation: .default
    )
    private var entries: FetchedResults<Entry>

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: EntryListViewModel(context: context))
    }

    var filteredEntries: [Entry] {
        if let predicate = viewModel.filterPredicate() {
            return entries.filter { entry in
                predicate.evaluate(with: entry)
            }
        }
        return Array(entries)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.warmPaper.ignoresSafeArea()

                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredEntries, id: \.id) { entry in
                                NavigationLink(destination: EntryDetailView(entry: entry)) {
                                    EntryCard(entry: entry, viewModel: viewModel)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("全部日记")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.warmAccent)
                            .font(.title2)
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "搜索日记")
        }
        .sheet(isPresented: $showingNewEntry) {
            EntryEditorView(context: viewContext)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed")
                .font(.system(size: 80))
                .foregroundColor(.warmGray)

            Text("还没有日记")
                .font(.warmHeadline)
                .foregroundColor(.warmBrown)

            Text("点击右上角的 + 开始记录")
                .font(.warmBody)
                .foregroundColor(.warmBrown.opacity(0.7))

            Button {
                showingNewEntry = true
            } label: {
                Text("创建第一篇日记")
                    .font(.warmBody)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.warmAccent)
                    .cornerRadius(24)
            }
        }
    }
}

struct EntryCard: View {
    @ObservedObject var entry: Entry
    let viewModel: EntryListViewModel
    @State private var thumbnails: [UIImage] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            if !entry.wrappedTitle.isEmpty {
                Text(entry.wrappedTitle)
                    .font(.warmHeadline)
                    .foregroundColor(.warmDark)
                    .lineLimit(2)
            }

            // 内容预览
            Text(entry.wrappedContent)
                .font(.warmBody)
                .foregroundColor(.warmBrown)
                .lineLimit(3)

            // 头部信息
            EntryHeader(entry: entry)

            // 缩略图预览
            if !thumbnails.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(thumbnails.prefix(3).enumerated()), id: \.offset) { _, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipped()
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .warmCard()
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteEntry(entry)
            } label: {
                Label("删除", systemImage: "trash")
            }

            Button {
                viewModel.toggleFavorite(entry)
            } label: {
                Label(
                    entry.isFavorite ? "取消收藏" : "收藏",
                    systemImage: entry.isFavorite ? "star.slash" : "star"
                )
            }
        }
        .task {
            await loadThumbnails()
        }
    }

    private func loadThumbnails() async {
        var images: [UIImage] = []
        for asset in entry.mediaAssetsArray.prefix(3) {
            if let image = await MediaService.shared.loadImage(filename: asset.wrappedFilename) {
                images.append(image)
            }
        }
        thumbnails = images
    }
}

#Preview {
    let context = CoreDataStack.shared.viewContext
    EntryListView(context: context)
        .environment(\.managedObjectContext, context)
}
