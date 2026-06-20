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
    var onNewEntry: () -> Void
    @Binding var isPresented: Bool

    @Environment(\.managedObjectContext) private var context
    @StateObject private var timelineVM: TimelineViewModel
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Entry.createdAt, ascending: false)],
        predicate: NSPredicate(format: "deletedAt == nil"),
        animation: .default
    ) private var entries: FetchedResults<Entry>
    @State private var sheetMode: SheetMode?

    init(notebook: Notebook, onNewEntry: @escaping () -> Void, isPresented: Binding<Bool>) {
        self.notebook = notebook
        self.onNewEntry = onNewEntry
        self._isPresented = isPresented
        self._timelineVM = StateObject(wrappedValue: TimelineViewModel(context: CoreDataStack.shared.viewContext))
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
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "E07050"))
                                    .padding(.horizontal, 16)
                                    .padding(.top, 20)
                                    .padding(.bottom, 8)

                                // 该月条目卡片（按日合并）
                                VStack(spacing: 0) {
                                    let flat = group.flatRows
                                    ForEach(Array(flat.enumerated()), id: \.element.entry.id) { idx, row in
                                        let isFirst = idx == 0
                                        let isLast  = idx == flat.count - 1
                                        let rowCorners: UIRectCorner = {
                                            var c: UIRectCorner = []
                                            if isFirst { c.formUnion([.topLeft, .topRight]) }
                                            if isLast  { c.formUnion([.bottomLeft, .bottomRight]) }
                                            return c
                                        }()

                                        SwipeToDeleteRow(corners: rowCorners) {
                                            row.entry.moveToTrash()
                                            try? context.save()
                                        } content: {
                                            TimelineEntryRow(entry: row.entry, showDate: row.showDate)
                                                .onTapGesture { sheetMode = .entryDetail(row.entry) }
                                        }
                                        .frame(minHeight: 60)

                                        if !isLast {
                                            Divider()
                                                .background(Color(hex: "3A3A42"))
                                                .padding(.leading, 60)
                                        }
                                    }
                                }
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
                .environment(\.managedObjectContext, context)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .calendar:
                ZStack {
                    Color(hex: "2A2A30").ignoresSafeArea()
                    CalendarView(viewModel: timelineVM)
                }
                .environment(\.managedObjectContext, context)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .newEntry:
                EntryEditorView(context: context)
                    .environment(\.managedObjectContext, context)
            case .entryDetail(let entry):
                EntryDetailView(entry: entry)
                    .environment(\.managedObjectContext, context)
            }
        }
    }
}

// MARK: - 按月分组

fileprivate struct EntryRow {
    let entry: Entry
    let showDate: Bool
}

fileprivate struct EntryGroup {
    let month: String
    let entries: [Entry]

    var flatRows: [EntryRow] {
        let cal = Calendar.current
        var rows: [EntryRow] = []
        var lastDay: DateComponents?
        for entry in entries {
            let comps = cal.dateComponents([.year, .month, .day], from: entry.createdAt ?? Date())
            let showDate = (comps != lastDay)
            rows.append(EntryRow(entry: entry, showDate: showDate))
            lastDay = comps
        }
        return rows
    }
}

extension NotebookDetailView {
    fileprivate var groupedEntries: [EntryGroup] {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月"
        var result: [EntryGroup] = []
        var current: (key: String, list: [Entry])?
        for entry in entries {
            let key = fmt.string(from: entry.createdAt ?? Date())
            if current?.key == key {
                current!.list.append(entry)
            } else {
                if let c = current { result.append(EntryGroup(month: c.key, entries: c.list)) }
                current = (key, [entry])
            }
        }
        if let c = current { result.append(EntryGroup(month: c.key, entries: c.list)) }
        return result
    }
}

// MARK: - 时间轴行

private struct TimelineEntryRow: View {
    @ObservedObject var entry: Entry
    let showDate: Bool
    @State private var thumbnails: [UIImage] = []

    private var weekdayString: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "EEE"
        let s = fmt.string(from: entry.createdAt ?? Date())
        // "周六" 直接返回；某些 locale 给出 "星期六" 截取后两字
        return s.hasPrefix("周") ? s : "周" + String(s.suffix(1))
    }

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

    private var coordinateString: String? {
        guard let loc = entry.location else { return nil }
        let lat = loc.latitude
        let lon = loc.longitude
        guard lat != 0 || lon != 0 else { return nil }
        let latDir = lat >= 0 ? "北" : "南"
        let lonDir = lon >= 0 ? "东" : "西"
        return String(format: "%.2f°%@, %.2f°%@", abs(lat), latDir, abs(lon), lonDir)
    }

    private var weatherString: String? {
        guard let loc = entry.location, loc.weatherCondition != nil else { return nil }
        let cond = loc.weatherCondition ?? ""
        return "\(Int(loc.weatherTemperature))°C \(cond)".trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧日期列
            VStack(spacing: 2) {
                if showDate {
                    Text(weekdayString)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(hex: "9090A0"))
                    Text(dayString)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "E8E8EE"))
                }
            }
            .frame(width: 36, alignment: .center)
            .padding(.top, showDate ? 0 : 0)

            // 文字信息
            VStack(alignment: .leading, spacing: 4) {
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hex: "E8E8EE"))
                        .lineLimit(2)
                } else {
                    Text(entry.wrappedContent)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hex: "E8E8EE"))
                        .lineLimit(2)
                }
                subtitleView
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

    private var subtitleView: some View {
        let sep = Text(" · ").foregroundColor(Color(hex: "5A5A68"))
        var line = Text(timeString).foregroundColor(Color(hex: "8A8A98"))
        if let coord = coordinateString {
            line = line + sep + Text(coord).foregroundColor(Color(hex: "8A8A98"))
        }
        if let w = weatherString {
            line = line + sep + Text(w).foregroundColor(Color(hex: "8A8A98"))
        }
        return line
            .font(.system(size: 12))
            .lineLimit(1)
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

// MARK: - 左滑删除容器

private struct SwipeToDeleteRow<Content: View>: View {
    let content: Content
    let onDelete: () -> Void
    let corners: UIRectCorner

    @State private var offset: CGFloat = 0

    private let deleteWidth: CGFloat = 92
    private let threshold: CGFloat = 50

    init(corners: UIRectCorner = [], onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.corners = corners
        self.onDelete = onDelete
        self.content = content()
    }

    // 滑动展开时右侧两角加圆角，与原有首尾圆角合并
    private var activeCorners: UIRectCorner {
        var c = corners
        if offset < 0 { c.formUnion([.topRight, .bottomRight]) }
        return c
    }

    var body: some View {
        content
            .background(
                activeCorners == []
                    ? AnyView(Color(hex: "32323A"))
                    : AnyView(Color(hex: "32323A").cornerRadius(12, corners: activeCorners))
            )
            // 红色删除按钮：固定在 content 右边缘之外，随 content offset 一起移动
            .overlay(alignment: .trailing) {
                Button { triggerDelete() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("删除")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 72)
                    .frame(maxHeight: .infinity)
                    .background(Color(hex: "C03828"))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                // 初始完全在右边缘外，留 20px 间距后才是按钮
                .offset(x: deleteWidth)
            }
            .offset(x: offset)
            .clipped()
            .contentShape(Rectangle())
        .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { value in
                        guard value.translation.width < 0 else {
                            if offset < 0 {
                                withAnimation(.interactiveSpring()) { offset = 0 }
                            }
                            return
                        }
                        let raw = value.translation.width
                        if -raw > deleteWidth {
                            offset = -(deleteWidth + (-raw - deleteWidth) * 0.2)
                        } else {
                            offset = raw
                        }
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        if -offset > threshold || velocity < -200 {
                            if -offset > deleteWidth * 1.6 || velocity < -400 {
                                triggerDelete()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = -deleteWidth
                                }
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                if offset < 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
                }
            }
    }

    private func triggerDelete() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            offset = -UIScreen.main.bounds.width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDelete()
        }
    }
}

#Preview {
    let context = CoreDataStack.shared.viewContext
    let nb = Notebook.make(style: .chevronTeal)
    return NotebookDetailView(
        notebook: nb,
        onNewEntry: {},
        isPresented: .constant(true)
    )
    .environment(\.managedObjectContext, context)
}
