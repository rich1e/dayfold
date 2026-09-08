// Views/Map/MapEntryCard.swift
import SwiftUI

struct MapEntryCard: View {
    @Environment(\.theme) private var theme
    let entries: [Entry]
    var onOpen: (Entry) -> Void
    var onDismiss: () -> Void

    /// 高度按"所有 page 中图片最多"的那个计算，防止 TabView 切换 page 时溢出
    private var estimatedHeight: CGFloat {
        let maxImages = entries.map { min($0.mediaAssetsArray.count, 3) }.max() ?? 0
        return maxImages > 0 ? 190 : 115
    }

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽把手
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.backgroundPressed)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 6)

            if entries.count == 1 {
                MapEntryCardItem(entry: entries[0], onOpen: onOpen)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .frame(height: estimatedHeight)
            } else {
                TabView {
                    ForEach(entries, id: \.objectID) { entry in
                        MapEntryCardItem(entry: entry, onOpen: onOpen)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 22)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: estimatedHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.backgroundSecondary)
                .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: -4)
        )
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 50 { onDismiss() }
                }
        )
    }
}

// MARK: - 子组件：承载单条 entry 的缩略图与文案渲染

private struct MapEntryCardItem: View {
    @Environment(\.theme) private var theme
    let entry: Entry
    var onOpen: (Entry) -> Void
    @State private var thumbnails: [UIImage] = []

    /// 媒体文件标识，asset 变化时重新加载缩略图（参考 EntryListView.EntryCard 的实现）
    private var thumbnailSourceID: String {
        entry.mediaAssetsArray.map { $0.wrappedFilename }.joined(separator: ",")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：日期 + 地点 + 天气图标
            HStack(spacing: 8) {
                Text(formatDate(entry.createdAt))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.accentPrimary)

                if let place = entry.location?.placeName, !place.isEmpty {
                    Text("·").foregroundColor(theme.textSecondary)
                    Text(place)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if let icon = entry.location?.weatherIcon, !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSecondary)
                }
            }

            // 标题
            if !entry.wrappedTitle.isEmpty {
                Text(entry.wrappedTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
            }

            // 缩略图预览（最多 3 张，60×60，圆角 8）
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

            // 文案预览（清洗掉 markdown 图片语法，避免残留 `![](filename)` 字样）
            let cleanContent = RichTextMarkdownParser.stripMarkdownImages(entry.wrappedContent)
            if !cleanContent.isEmpty {
                Text(cleanContent)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textPrimary.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { onOpen(entry) }
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

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy.MM.dd"
        return fmt.string(from: date)
    }
}
