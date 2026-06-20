// Views/Entry/TrashView.swift
import SwiftUI
import CoreData

struct TrashView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.deletedAt, order: .reverse)],
        predicate: NSPredicate(format: "deletedAt != nil"),
        animation: .default
    )
    private var trashedEntries: FetchedResults<Entry>

    @State private var showingClearConfirm = false

    private var viewModel: EntryListViewModel {
        EntryListViewModel(context: viewContext)
    }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if trashedEntries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
        }
        .confirmationDialog("确认清空回收箱？删除后无法恢复。", isPresented: $showingClearConfirm, titleVisibility: .visible) {
            Button("全部删除", role: .destructive) { clearAll() }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack {
            // 全部删除
            Button {
                showingClearConfirm = true
            } label: {
                Text("全部删除")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "C03828"))
                    .cornerRadius(20)
            }
            .disabled(trashedEntries.isEmpty)
            .opacity(trashedEntries.isEmpty ? 0.4 : 1)

            Spacer()

            Text("回收箱")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            // 关闭按钮
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.22, green: 0.22, blue: 0.24))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.68))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(red: 0.10, green: 0.10, blue: 0.10))
    }

    // MARK: - 列表

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedEntries, id: \.dayKey) { group in
                    // 日期标题
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(group.weekday)
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.58))
                            Text(group.day)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 44, alignment: .leading)
                        .padding(.leading, 16)

                        // 该天的条目
                        VStack(spacing: 0) {
                            ForEach(Array(group.entries.enumerated()), id: \.element.id) { idx, entry in
                                TrashEntryRow(entry: entry) {
                                    restore(entry)
                                } onDelete: {
                                    permanentlyDelete(entry)
                                }

                                if idx < group.entries.count - 1 {
                                    Divider()
                                        .background(Color(red: 0.22, green: 0.22, blue: 0.24))
                                }
                            }
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "trash")
                .font(.system(size: 52))
                .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))
            Text("回收箱为空")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.48))
            Spacer()
        }
    }

    // MARK: - 分组

    private struct DayGroup {
        let dayKey: String
        let weekday: String
        let day: String
        let entries: [Entry]
    }

    private var groupedEntries: [DayGroup] {
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "yyyy-MM-dd"
        let weekdayFmt = DateFormatter()
        weekdayFmt.locale = Locale(identifier: "zh_CN")
        weekdayFmt.dateFormat = "EEEE"
        let dayNumFmt = DateFormatter()
        dayNumFmt.dateFormat = "d"

        var result: [DayGroup] = []
        var current: (key: String, list: [Entry])?
        for entry in trashedEntries {
            let date = entry.deletedAt ?? Date()
            let key = dayFmt.string(from: date)
            if current?.key == key {
                current!.list.append(entry)
            } else {
                if let c = current {
                    let d = dayFmt.date(from: c.key) ?? Date()
                    result.append(DayGroup(
                        dayKey: c.key,
                        weekday: weekdayFmt.string(from: d),
                        day: dayNumFmt.string(from: d),
                        entries: c.list
                    ))
                }
                current = (key, [entry])
            }
        }
        if let c = current {
            let d = dayFmt.date(from: c.key) ?? Date()
            result.append(DayGroup(
                dayKey: c.key,
                weekday: weekdayFmt.string(from: d),
                day: dayNumFmt.string(from: d),
                entries: c.list
            ))
        }
        return result
    }

    // MARK: - Actions

    private func restore(_ entry: Entry) {
        entry.restore()
        try? viewContext.save()
    }

    private func permanentlyDelete(_ entry: Entry) {
        for asset in entry.mediaAssetsArray {
            if let filename = asset.filename {
                Task { await MediaService.shared.deleteImage(filename: filename) }
            }
            viewContext.delete(asset)
        }
        if let location = entry.location { viewContext.delete(location) }
        viewContext.delete(entry)
        try? viewContext.save()
    }

    private func clearAll() {
        for entry in trashedEntries {
            permanentlyDelete(entry)
        }
    }
}

// MARK: - 条目行

private struct TrashEntryRow: View {
    @ObservedObject var entry: Entry
    var onRestore: () -> Void
    var onDelete: () -> Void

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: entry.deletedAt ?? Date())
    }

    private var meta: String {
        var parts = [timeString]
        if let place = entry.location?.wrappedPlaceName, !place.isEmpty {
            parts.append(place)
        }
        if let loc = entry.location, loc.weatherCondition != nil {
            parts.append("\(Int(loc.weatherTemperature))°C \(loc.weatherCondition ?? "")")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("日记本")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "5BC8D8"))
                    Text(meta)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.65))
                        .lineLimit(1)
                }
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.78))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 14)

            Spacer()
        }
        .padding(.leading, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onDelete() } label: {
                Label("彻底删除", systemImage: "trash.fill")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { onRestore() } label: {
                Label("恢复", systemImage: "arrow.uturn.backward")
            }
            .tint(Color(hex: "5BC8D8"))
        }
    }
}

#Preview {
    TrashView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
