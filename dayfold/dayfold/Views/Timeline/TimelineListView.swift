// Views/Timeline/TimelineListView.swift
import SwiftUI

struct TimelineListView: View {
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)],
        animation: .default
    )
    private var entries: FetchedResults<Entry>

    var groupedEntries: [(String, [Entry])] {
        Dictionary(grouping: Array(entries)) { entry in
            formatDate(entry.createdAt ?? Date())
        }
        .sorted { $0.key > $1.key }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedEntries, id: \.0) { date, dayEntries in
                    Section {
                        ForEach(dayEntries, id: \.id) { entry in
                            NavigationLink(destination: EntryDetailView(entry: entry)) {
                                TimelineEntryCard(entry: entry)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    } header: {
                        Text(date)
                            .font(.warmHeadline)
                            .foregroundColor(.warmDark)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.warmCream)
                    }
                }
            }
        }
        .background(Color.warmPaper)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月dd日 EEEE"
            return formatter.string(from: date)
        }
    }
}

struct TimelineEntryCard: View {
    let entry: Entry
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间标记
            VStack(spacing: 4) {
                let time = entry.createdAt ?? Date()
                Text(time, format: .dateTime.hour().minute())
                    .font(.warmCaption)
                    .foregroundColor(.warmBrown)

                Circle()
                    .fill(Color.warmAccent)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 60)

            // 内容
            VStack(alignment: .leading, spacing: 8) {
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.warmHeadline)
                        .foregroundColor(.warmDark)
                }

                Text(entry.wrappedContent)
                    .font(.warmBody)
                    .foregroundColor(.warmBrown)
                    .lineLimit(2)

                // 缩略图
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(8)
                }

                // 元信息
                HStack(spacing: 8) {
                    if let location = entry.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                            Text(location.wrappedPlaceName)
                        }
                        .font(.warmFootnote)
                        .foregroundColor(.warmAccent)
                    }

                    if !entry.tagsArray.isEmpty {
                        ForEach(entry.tagsArray.prefix(2), id: \.id) { tag in
                            Text(tag.wrappedName)
                                .font(.warmFootnote)
                                .foregroundColor(tag.displayColor)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .warmCard()
        .task {
            if let firstAsset = entry.mediaAssetsArray.first {
                thumbnail = await MediaService.shared.loadImage(filename: firstAsset.wrappedFilename)
            }
        }
    }
}
