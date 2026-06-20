// Views/NotebookDetailView.swift
import SwiftUI
import CoreData

private enum SheetMode: Identifiable {
    case photos, calendar, newEntry, entryDetail(Entry)
    var id: String {
        switch self {
        case .photos: return "photos"
        case .calendar: return "calendar"
        case .newEntry: return "newEntry"
        case .entryDetail(let e): return "detail-\(e.objectID)"
        }
    }
}

struct NotebookDetailView: View {
    let notebook: Notebook
    let context: NSManagedObjectContext
    var onNewEntry: () -> Void
    @Binding var isPresented: Bool

    @StateObject private var timelineVM: TimelineViewModel
    @FetchRequest private var entries: FetchedResults<Entry>
    @State private var sheetMode: SheetMode?

    init(notebook: Notebook, context: NSManagedObjectContext, onNewEntry: @escaping () -> Void, isPresented: Binding<Bool>) {
        self.notebook = notebook
        self.context = context
        self.onNewEntry = onNewEntry
        self._isPresented = isPresented
        self._timelineVM = StateObject(wrappedValue: TimelineViewModel(context: context))
        self._entries = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Entry.createdAt, ascending: false)],
            animation: .default
        )
    }

    var latestDate: String {
        guard let date = entries.first?.createdAt else { return "—" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd"
        return fmt.string(from: date)
    }

    var body: some View {
        ZStack {
            Color(hex: "2A2A30").ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "5BC8D8"))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Button { sheetMode = .photos } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor({ if case .photos = sheetMode { return Color(hex: "5BC8D8") }; return Color(hex: "9090A0") }())
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button { sheetMode = .calendar } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor({ if case .calendar = sheetMode { return Color(hex: "5BC8D8") }; return Color(hex: "9090A0") }())
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                // 标题区
                VStack(spacing: 4) {
                    Text(notebook.name)
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(Color(hex: "D4A574"))
                        .tracking(3)

                    Text("\(latestDate) / \(entries.count) PHOTOS")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "7A7A88"))
                        .tracking(1)
                }
                .padding(.top, 8)
                .padding(.bottom, 20)

                // 日记列表
                if entries.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "4A4A58"))
                        Text("还没有日记")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "6A6A78"))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                            ForEach(groupedEntries, id: \.month) { group in
                                // 月份标题
                                Text(group.month)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(hex: "E07050"))
                                    .tracking(1)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 20)
                                    .padding(.bottom, 8)

                                // 该月条目卡片
                                VStack(spacing: 0) {
                                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { idx, entry in
                                        TimelineEntryRow(entry: entry)
                                            .onTapGesture { sheetMode = .entryDetail(entry) }

                                        if idx < group.entries.count - 1 {
                                            Divider()
                                                .background(Color(hex: "3A3A42"))
                                                .padding(.leading, 56)
                                        }
                                    }
                                }
                                .background(Color(hex: "32323A"))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }

            // 底部 + 按钮
            VStack {
                Spacer()
                Button { sheetMode = .newEntry } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "4DB6AC"))
                            .frame(width: 56, height: 56)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Color(hex: "1A1A1B"))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 48)
            }
        }
        .sheet(item: $sheetMode) { mode in
            switch mode {
            case .photos:
                ZStack {
                    Color(hex: "2A2A30").ignoresSafeArea()
                    PhotoWallView(viewModel: timelineVM, onSelectEntry: { entry in
                        sheetMode = .entryDetail(entry)
                    })
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .calendar:
                ZStack {
                    Color(hex: "2A2A30").ignoresSafeArea()
                    CalendarView(viewModel: timelineVM)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .newEntry:
                EntryEditorView(context: context)
            case .entryDetail(let entry):
                EntryDetailView(entry: entry)
            }
        }
    }
}

// MARK: - 按月分组

fileprivate struct EntryGroup {
    let month: String
    let entries: [Entry]
}

extension NotebookDetailView {
    fileprivate var groupedEntries: [EntryGroup] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        fmt.locale = Locale(identifier: "en_US")
        var result: [EntryGroup] = []
        var current: (key: String, list: [Entry])?
        for entry in entries {
            let key = fmt.string(from: entry.createdAt ?? Date())
            if current?.key == key {
                current!.list.append(entry)
            } else {
                if let c = current { result.append(EntryGroup(month: c.key.uppercased(), entries: c.list)) }
                current = (key, [entry])
            }
        }
        if let c = current { result.append(EntryGroup(month: c.key.uppercased(), entries: c.list)) }
        return result
    }
}

// MARK: - 时间轴行

private struct TimelineEntryRow: View {
    @ObservedObject var entry: Entry
    @State private var thumbnails: [UIImage] = []

    private var dayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        return fmt.string(from: entry.createdAt ?? Date())
    }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: entry.createdAt ?? Date())
    }

    private var subtitle: String {
        var parts: [String] = [timeString]
        if let loc = entry.location, !loc.wrappedPlaceName.isEmpty {
            parts.append(loc.wrappedPlaceName)
        }
        if let loc = entry.location, loc.weatherCondition != nil {
            parts.append("\(Int(loc.weatherTemperature))°C")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            // 日期数字
            Text(dayString)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color(hex: "E07050"))
                .frame(width: 44, alignment: .center)

            // 文字信息
            VStack(alignment: .leading, spacing: 3) {
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "E8E8EE"))
                        .lineLimit(1)
                } else {
                    Text(entry.wrappedContent)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "E8E8EE"))
                        .lineLimit(1)
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "7A7A88"))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // 右侧缩略图
            if !thumbnails.isEmpty {
                thumbnailGrid
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .task(id: entry.mediaAssetsArray.map(\.wrappedFilename).joined()) {
            await loadThumbnails()
        }
    }

    private var thumbnailGrid: some View {
        let imgs = thumbnails.prefix(3)
        let extra = thumbnails.count - 3
        return ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 2) {
                ForEach(Array(imgs.enumerated()), id: \.offset) { _, img in
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipped()
                        .cornerRadius(4)
                }
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .offset(x: -2, y: -2)
            }
        }
        .frame(height: 36)
    }

    private func loadThumbnails() async {
        var imgs: [UIImage] = []
        for asset in entry.mediaAssetsArray.prefix(4) {
            if let img = await MediaService.shared.loadImage(filename: asset.wrappedFilename) {
                imgs.append(img)
            }
        }
        thumbnails = imgs
    }
}

#Preview {
    let context = CoreDataStack.shared.viewContext
    let nb = Notebook.make(style: .chevronTeal)
    return NotebookDetailView(
        notebook: nb,
        context: context,
        onNewEntry: {},
        isPresented: .constant(true)
    )
    .environment(\.managedObjectContext, context)
}
