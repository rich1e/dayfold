// Views/Timeline/PhotoWallView.swift
import SwiftUI

struct PhotoWallView: View {
    @ObservedObject var viewModel: TimelineViewModel
    var scrollTarget: UUID?
    var onSelectEntry: ((Entry) -> Void)?

    private var entries: [Entry] { viewModel.entriesWithPhotos }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if entries.isEmpty {
                    emptyState
                } else {
                    PhotoWallGrid(
                        entries: entries,
                        onNavigate: { entry in
                            onSelectEntry?(entry)
                        }
                    )
                    .padding(2)
                }
            }
            .background(Color.warmPaper)
            .onChange(of: scrollTarget) { target in
                if let target = target {
                    withAnimation {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundColor(.warmGray)
            Text("还没有带图片的记录")
                .font(.warmHeadline)
                .foregroundColor(.warmBrown)
            Text("拍张照片开始吧")
                .font(.warmBody)
                .foregroundColor(.warmGray)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

struct PhotoWallGrid: View {
    let entries: [Entry]
    var onNavigate: (Entry) -> Void

    // 布局计算：收藏条目占2×2大格（不连续），其余小格
    private var layout: [(entry: Entry, isLarge: Bool)] {
        var result: [(Entry, Bool)] = []
        var lastWasLarge = false
        for entry in entries {
            let makeLarge = entry.isFavorite && !lastWasLarge
            result.append((entry, makeLarge))
            lastWasLarge = makeLarge
        }
        return result
    }

    private let cellSpacing: CGFloat = 2
    private let columnCount = 3

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let cellSize = (screenWidth - cellSpacing * CGFloat(columnCount + 1)) / CGFloat(columnCount)

        return Group {
            // 使用自定义布局：按行排列，大格占2列2行
            photoWallContent(cellSize: cellSize)
        }
    }

    private func photoWallContent(cellSize: CGFloat) -> some View {
        var rows: [[( entry: Entry, isLarge: Bool, colSpan: Int)]] = []
        var currentRow: [(entry: Entry, isLarge: Bool, colSpan: Int)] = []
        var currentColCount = 0

        for item in layout {
            let span = item.isLarge ? 2 : 1
            if currentColCount + span > columnCount {
                rows.append(currentRow)
                currentRow = []
                currentColCount = 0
            }
            currentRow.append((item.entry, item.isLarge, span))
            currentColCount += span
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        return LazyVStack(spacing: cellSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: cellSpacing) {
                    ForEach(row, id: \.entry.id) { item in
                        let size = item.isLarge
                            ? CGSize(width: cellSize * 2 + cellSpacing, height: cellSize * 2 + cellSpacing)
                            : CGSize(width: cellSize, height: cellSize)

                        PhotoWallCell(
                            entry: item.entry,
                            size: size,
                            isLarge: item.isLarge,
                            onTap: onNavigate
                        )
                        .id(item.entry.id)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

struct PhotoWallCell: View {
    let entry: Entry
    let size: CGSize
    let isLarge: Bool
    var onTap: (Entry) -> Void = { _ in }

    @State private var thumbnail: UIImage?

    var body: some View {
        Button {
            onTap(entry)
        } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.warmCream
                        ProgressView()
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()

                // 角标
                VStack(alignment: .trailing, spacing: 4) {
                    if isLarge {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.warmAccent)
                            .padding(4)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(4)
                    }
                    let count = entry.mediaAssetsArray.count
                    if count >= 2 {
                        HStack(spacing: 2) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 9))
                            Text("\(count)")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(4)
                    }
                }
                .padding(4)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button {
                // 跳转编辑由调用方处理
            } label: {
                Label("编辑条目", systemImage: "pencil")
            }
            Button {
                toggleFavorite()
            } label: {
                Label(
                    entry.isFavorite ? "取消收藏" : "加入收藏",
                    systemImage: entry.isFavorite ? "star.slash" : "star"
                )
            }
        }
        .task {
            if let asset = entry.mediaAssetsArray.first {
                thumbnail = await MediaService.shared.loadImage(filename: asset.wrappedFilename)
            }
        }
    }

    private func toggleFavorite() {
        let context = entry.managedObjectContext ?? CoreDataStack.shared.viewContext
        entry.isFavorite.toggle()
        try? context.save()
    }
}
