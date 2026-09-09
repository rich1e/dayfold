// Views/Timeline/EntryBottomSheet.swift
import SwiftUI

private enum SheetHeight {
    static let collapsed: CGFloat = 80
    static let medium: CGFloat = 320
    static let expanded: CGFloat = UIScreen.main.bounds.height * 0.85
}

struct EntryBottomSheet: View {
    @Environment(\.theme) private var theme
    let selectedDate: Date?
    let entries: [Entry]
    @Binding var viewMode: TimelineViewMode
    @Binding var photoWallScrollTarget: UUID?
    var onCreateEntry: (Date) -> Void

    @State private var sheetHeight: CGFloat = SheetHeight.collapsed
    @GestureState private var dragOffset: CGFloat = 0

    private var currentHeight: CGFloat {
        min(SheetHeight.expanded, max(SheetHeight.collapsed, sheetHeight - dragOffset))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽把手
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.backgroundPressed)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // 摘要条
            summaryBar

            // 条目列表（中档/全屏时显示）
            if sheetHeight > SheetHeight.collapsed + 20 {
                Divider().padding(.horizontal)
                entryList
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: currentHeight)
        .background(
            // 背景高度比内容高 34pt，延伸到屏底覆盖 home indicator（消除底部间隙）；
            // SwiftUI 不裁剪，背景可超出 frame 范围绘制，但父空间仍只占 currentHeight
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 20
            )
            .fill(theme.backgroundSecondary)
            .frame(height: currentHeight + 34)
            .offset(y: 34)
            .shadow(color: theme.backgroundPressed.opacity(0.4), radius: 12, x: 0, y: -4)
        )
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    snapSheet(translation: value.translation.height)
                }
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: sheetHeight)
    }

    private var summaryBar: some View {
        HStack {
            if let date = selectedDate {
                Text(formatSelectedDate(date))
                    .font(.warmHeadline)
                    .foregroundColor(theme.textPrimary)
                if !entries.isEmpty {
                    Text("·")
                        .foregroundColor(theme.textSecondary)
                    Text("\(entries.count)条记录")
                        .font(.warmBody)
                        .foregroundColor(theme.textSecondary)
                } else {
                    Text("这天还没有记录")
                        .font(.warmBody)
                        .foregroundColor(theme.textSecondary)
                }
            } else {
                Text("选择一天查看记录")
                    .font(.warmBody)
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
            if let date = selectedDate {
                Button {
                    onCreateEntry(date)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.accentPrimary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                sheetHeight = sheetHeight <= SheetHeight.collapsed + 20
                    ? SheetHeight.medium
                    : SheetHeight.collapsed
            }
        }
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(entries, id: \.id) { entry in
                    NavigationLink(destination: EntryDetailView(entry: entry)) {
                        sheetEntryCard(entry: entry)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }

    private func sheetEntryCard(entry: Entry) -> some View {
        SheetEntryCardRow(
            entry: entry,
            photoWallScrollTarget: $photoWallScrollTarget,
            viewMode: $viewMode
        )
        .padding(12)
        .background(theme.backgroundTertiary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.dividerPrimary, lineWidth: 1)
        )
    }

    private func snapSheet(translation: CGFloat) {
        let anchors: [CGFloat] = [SheetHeight.collapsed, SheetHeight.medium, SheetHeight.expanded]
        let target = sheetHeight - translation
        let nearest = anchors.min(by: { abs($0 - target) < abs($1 - target) }) ?? SheetHeight.collapsed
        sheetHeight = nearest
    }

    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

// MARK: - 单条 entry 卡片（缩略图 + 清洗 markdown）
private struct SheetEntryCardRow: View {
    @Environment(\.theme) private var theme
    let entry: Entry
    @Binding var photoWallScrollTarget: UUID?
    @Binding var viewMode: TimelineViewMode

    @State private var thumbnails: [UIImage] = []

    private var thumbnailSourceID: String {
        entry.mediaAssetsArray.map { $0.wrappedFilename }.joined(separator: ",")
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.warmHeadline)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }

                // 缩略图预览（最多 3 张，44×44 圆角）
                if !thumbnails.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(thumbnails.prefix(3).enumerated()), id: \.offset) { _, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipped()
                                .cornerRadius(6)
                        }
                    }
                }

                // 文案预览（剥离 markdown 图片语法，避免残留 `![](filename)`）
                let cleanContent = RichTextMarkdownParser.stripMarkdownImages(entry.wrappedContent)
                if !cleanContent.isEmpty {
                    Text(cleanContent)
                        .font(.warmBody)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }

                if let createdAt = entry.createdAt {
                    Text(createdAt, format: .dateTime.hour().minute())
                        .font(.warmCaption)
                        .foregroundColor(theme.backgroundPressed)
                }
            }
            Spacer()
            if !entry.mediaAssetsArray.isEmpty {
                Button {
                    photoWallScrollTarget = entry.id
                    viewMode = .photoWall
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(theme.accentPrimary)
                }
            }
        }
        .task(id: thumbnailSourceID) {
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
