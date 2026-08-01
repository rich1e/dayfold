// Views/Entry/EntryListView.swift
import SwiftUI
import CoreData

struct EntryListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: EntryListViewModel
    @State private var isPresentingTagPicker = false
    @State private var tagSelectionDraft: Set<Tag> = []
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)],
        predicate: NSPredicate(format: "deletedAt == nil"),
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
            VStack(spacing: 0) {
                filterBar
                ZStack {
                    Color.warmPaper.ignoresSafeArea()

                    if filteredEntries.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
                                    NavigationLink(destination: EntryDetailView(entry: entry)) {
                                        EntryCard(entry: entry, viewModel: viewModel)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .transition(.paperDrop)
                                    .animation(
                                        .easeOut(duration: 0.38).delay(Double(min(index, 7)) * 0.07),
                                        value: filteredEntries.count
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("全部日记")
            .searchable(text: $viewModel.searchText, prompt: "搜索日记")
            .sheet(isPresented: $isPresentingTagPicker, onDismiss: {
                viewModel.selectedTags = tagSelectionDraft
                // 清理已删 tag 的死引用
                viewModel.selectedTags = viewModel.selectedTags.filter { $0.managedObjectContext != nil }
            }) {
                NavigationView {
                    TagFilterSheet(selection: $tagSelectionDraft, allTags: viewModel.allTags)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.showFavoritesOnly.toggle()
            } label: {
                Image(systemName: viewModel.showFavoritesOnly ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundColor(viewModel.showFavoritesOnly ? .warmAccent : .warmBrown)
                    .frame(width: 32, height: 32)
            }
            Button {
                tagSelectionDraft = viewModel.selectedTags
                isPresentingTagPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                    Text(viewModel.selectedTags.isEmpty
                         ? "筛选标签"
                         : "\(viewModel.selectedTags.count) 个标签")
                        .foregroundColor(viewModel.selectedTags.isEmpty ? .warmBrown : .warmAccent)
                }
                .font(.system(size: 14))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.warmLight)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed")
                .font(.system(size: 80))
                .foregroundColor(.warmGray)

            Text("还没有日记")
                .font(.warmHeadline)
                .foregroundColor(.warmBrown)

            Text("点击右下角的 + 开始记录")
                .font(.warmBody)
                .foregroundColor(.warmBrown.opacity(0.7))
        }
    }
}

struct EntryCard: View {
    @ObservedObject var entry: Entry
    let viewModel: EntryListViewModel
    @State private var thumbnails: [UIImage] = []
    @State private var isPressed = false

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
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .task(id: thumbnailSourceID) {
            await loadThumbnails()
        }
    }

    // 媒体文件标识，变化时重新加载缩略图（编辑增删图片后即时刷新）
    private var thumbnailSourceID: String {
        entry.mediaAssetsArray.map { $0.wrappedFilename }.joined(separator: ",")
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

private struct TagFilterSheet: View {
    @Binding var selection: Set<Tag>
    let allTags: [Tag]

    var body: some View {
        List {
            ForEach(allTags, id: \.objectID) { tag in
                Button {
                    if selection.contains(tag) { selection.remove(tag) }
                    else { selection.insert(tag) }
                } label: {
                    HStack {
                        Text(tag.wrappedName)
                            .foregroundColor(.warmDark)
                        Spacer()
                        if selection.contains(tag) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.warmAccent)
                        }
                    }
                }
            }
        }
        .navigationTitle("筛选标签(AND)")
        .listStyle(.plain)
    }
}

#Preview {
    let context = CoreDataStack.shared.viewContext
    EntryListView(context: context)
        .environment(\.managedObjectContext, context)
}
