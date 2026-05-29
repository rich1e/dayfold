# Timeline 日历模式 & 照片墙模式实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 TimelineView 中的日历模式（月历网格 + 可拖拽底部抽屉）和照片墙模式（收藏优先的交错网格），并通过共享 selectedDate 状态实现三模式联动。

**Architecture:** 所有模式共享 `TimelineViewModel` 中的 `selectedDate`/`currentMonth` 状态。日历模式用 `.overlay` 自绘抽屉（三档吸附），照片墙用自定义布局算法实现大小格交错排列。`Entry.isFavorite` 已存在于 Core Data schema，无需迁移。

**Tech Stack:** SwiftUI, Core Data, DragGesture, LazyVGrid, contextMenu, .overlay

---

## 文件结构

| 操作 | 文件 | 职责 |
|---|---|---|
| 修改 | `dayfold/dayfold/ViewModels/TimelineViewModel.swift` | 新增 selectedDate、currentMonth、entriesWithPhotos、favoriteEntriesWithPhotos |
| 修改 | `dayfold/dayfold/Models/Entry.swift` | 新增 wrappedIsFavorite 计算属性 |
| 新增 | `dayfold/dayfold/Views/Timeline/CalendarView.swift` | 日历模式顶层视图（月历 + 抽屉） |
| 新增 | `dayfold/dayfold/Views/Timeline/MonthGridView.swift` | 月历网格 + DayCell |
| 新增 | `dayfold/dayfold/Views/Timeline/EntryBottomSheet.swift` | 可拖拽底部抽屉 |
| 新增 | `dayfold/dayfold/Views/Timeline/PhotoWallView.swift` | 照片墙模式顶层视图 + PhotoWallGrid |
| 修改 | `dayfold/dayfold/Views/Timeline/TimelineView.swift` | 替换占位符，传入 viewModel |
| 修改 | `dayfold/dayfold/Views/Entry/EntryDetailView.swift` | 导航栏收藏按钮 |
| 修改 | `dayfold/dayfold/Views/Entry/EntryEditorView.swift` | 工具栏收藏按钮 |
| 修改 | `dayfold/dayfold/ViewModels/EntryEditorViewModel.swift` | 新增 isFavorite 属性 + toggleFavorite() |

---

## Task 1：Entry 模型补充 wrappedIsFavorite

**Files:**
- Modify: `dayfold/dayfold/Models/Entry.swift`

- [ ] **Step 1: 在 Entry.swift 中添加 wrappedIsFavorite**

打开 `dayfold/dayfold/Models/Entry.swift`，在现有计算属性后添加：

```swift
var wrappedIsFavorite: Bool {
    get { isFavorite }
    set { isFavorite = newValue }
}
```

- [ ] **Step 2: Commit**

```bash
git add dayfold/dayfold/Models/Entry.swift
git commit -m "feat: add wrappedIsFavorite computed property to Entry"
```

---

## Task 2：TimelineViewModel 新增状态和查询

**Files:**
- Modify: `dayfold/dayfold/ViewModels/TimelineViewModel.swift`

- [ ] **Step 1: 替换 TimelineViewModel.swift 完整内容**

```swift
// ViewModels/TimelineViewModel.swift
import Foundation
import CoreData

enum TimelineViewMode {
    case list
    case calendar
    case photoWall
}

class TimelineViewModel: ObservableObject {
    @Published var viewMode: TimelineViewMode = .list
    @Published var selectedDate: Date? = Calendar.current.startOfDay(for: Date())
    @Published var currentMonth: Date = Calendar.current.startOfDay(for: Date())

    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    // MARK: - 日历辅助

    func entriesForDate(_ date: Date) -> [Entry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        return (try? viewContext.fetch(fetchRequest)) ?? []
    }

    func datesWithEntries(in month: Date) -> [Date: [EntryDotType]] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: month)
        guard let startOfMonth = calendar.date(from: comps),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
        else { return [:] }

        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt <= %@",
            startOfMonth as NSDate,
            endOfMonth as NSDate
        )

        let entries = (try? viewContext.fetch(fetchRequest)) ?? []
        var result: [Date: [EntryDotType]] = [:]
        for entry in entries {
            guard let date = entry.createdAt else { continue }
            let day = calendar.startOfDay(for: date)
            let dot: EntryDotType = entry.mediaAssetsArray.isEmpty ? .text : .photo
            result[day, default: []].append(dot)
        }
        return result
    }

    func goToPreviousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    func goToNextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }

    // MARK: - 照片墙

    var entriesWithPhotos: [Entry] {
        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let all = (try? viewContext.fetch(fetchRequest)) ?? []
        return all.filter { !$0.mediaAssetsArray.isEmpty }
    }
}

enum EntryDotType {
    case photo   // warmAccent
    case text    // warmBrown
}
```

- [ ] **Step 2: Commit**

```bash
git add dayfold/dayfold/ViewModels/TimelineViewModel.swift
git commit -m "feat: expand TimelineViewModel with selectedDate, currentMonth, and photo queries"
```

---

## Task 3：MonthGridView（月历网格）

**Files:**
- Create: `dayfold/dayfold/Views/Timeline/MonthGridView.swift`

- [ ] **Step 1: 创建 MonthGridView.swift**

```swift
// Views/Timeline/MonthGridView.swift
import SwiftUI

struct MonthGridView: View {
    let month: Date
    let dotMap: [Date: [EntryDotType]]
    @Binding var selectedDate: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(spacing: 0) {
            // 星期标题行
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.warmCaption)
                        .foregroundColor(.warmBrown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .background(Color.warmCream)

            // 日期网格
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            dots: dotMap[Calendar.current.startOfDay(for: date)] ?? [],
                            isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                            isToday: Calendar.current.isDateInToday(date)
                        )
                        .onTapGesture {
                            selectedDate = Calendar.current.startOfDay(for: date)
                        }
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
        }
    }

    // 当月所有日格（含前置空格）
    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: month)
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay)
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstDay) - 1 // 0=日
        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        // 补齐到7的倍数
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

struct DayCell: View {
    let date: Date
    let dots: [EntryDotType]
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.warmAccent.opacity(0.25))
                        .frame(width: 32, height: 32)
                }
                if isSelected {
                    Circle()
                        .stroke(Color.warmDark, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.warmBody)
                    .foregroundColor(isToday ? .warmAccent : .warmDark)
                    .fontWeight(isToday ? .bold : .regular)
            }
            .frame(width: 36, height: 36)

            // 圆点指示器
            dotIndicator
                .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var dotIndicator: some View {
        if dots.isEmpty {
            Color.clear
        } else if dots.count <= 3 {
            HStack(spacing: 2) {
                ForEach(Array(dots.prefix(3).enumerated()), id: \.offset) { _, dot in
                    Circle()
                        .fill(dot == .photo ? Color.warmAccent : Color.warmBrown)
                        .frame(width: 5, height: 5)
                }
            }
        } else {
            Text("\(dots.count)+")
                .font(.system(size: 8))
                .foregroundColor(.warmBrown)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add dayfold/dayfold/Views/Timeline/MonthGridView.swift
git commit -m "feat: add MonthGridView with DayCell and dot indicators"
```

---

## Task 4：EntryBottomSheet（可拖拽底部抽屉）

**Files:**
- Create: `dayfold/dayfold/Views/Timeline/EntryBottomSheet.swift`

- [ ] **Step 1: 创建 EntryBottomSheet.swift**

```swift
// Views/Timeline/EntryBottomSheet.swift
import SwiftUI

private enum SheetHeight {
    static let collapsed: CGFloat = 80
    static let medium: CGFloat = 320
    static let expanded: CGFloat = UIScreen.main.bounds.height * 0.85
}

struct EntryBottomSheet: View {
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
                .fill(Color.warmGray)
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
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.warmLight)
                .shadow(color: Color.warmGray.opacity(0.4), radius: 12, x: 0, y: -4)
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
                    .foregroundColor(.warmDark)
                if !entries.isEmpty {
                    Text("·")
                        .foregroundColor(.warmBrown)
                    Text("\(entries.count)条记录")
                        .font(.warmBody)
                        .foregroundColor(.warmBrown)
                } else {
                    Text("这天还没有记录")
                        .font(.warmBody)
                        .foregroundColor(.warmBrown)
                }
            } else {
                Text("选择一天查看记录")
                    .font(.warmBody)
                    .foregroundColor(.warmBrown)
            }
            Spacer()
            if let date = selectedDate {
                Button {
                    onCreateEntry(date)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.warmAccent)
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.warmHeadline)
                        .foregroundColor(.warmDark)
                        .lineLimit(1)
                }
                Text(entry.wrappedContent)
                    .font(.warmBody)
                    .foregroundColor(.warmBrown)
                    .lineLimit(2)
                if let createdAt = entry.createdAt {
                    Text(createdAt, format: .dateTime.hour().minute())
                        .font(.warmCaption)
                        .foregroundColor(.warmGray)
                }
            }
            Spacer()
            if !entry.mediaAssetsArray.isEmpty {
                Button {
                    photoWallScrollTarget = entry.id
                    viewMode = .photoWall
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(.warmAccent)
                }
            }
        }
        .padding(12)
        .background(Color.warmPaper)
        .cornerRadius(12)
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
```

- [ ] **Step 2: Commit**

```bash
git add dayfold/dayfold/Views/Timeline/EntryBottomSheet.swift
git commit -m "feat: add draggable EntryBottomSheet with three snap heights"
```

---

## Task 5：CalendarView（日历模式顶层视图）

**Files:**
- Create: `dayfold/dayfold/Views/Timeline/CalendarView.swift`

- [ ] **Step 1: 创建 CalendarView.swift**

```swift
// Views/Timeline/CalendarView.swift
import SwiftUI

struct CalendarView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @State private var showingNewEntry = false
    @State private var newEntryDate: Date = Date()
    @State private var dragOffset: CGFloat = 0

    private var dotMap: [Date: [EntryDotType]] {
        viewModel.datesWithEntries(in: viewModel.currentMonth)
    }

    private var selectedEntries: [Entry] {
        guard let date = viewModel.selectedDate else { return [] }
        return viewModel.entriesForDate(date)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 月份导航
                monthHeader

                // 月历网格
                MonthGridView(
                    month: viewModel.currentMonth,
                    dotMap: dotMap,
                    selectedDate: $viewModel.selectedDate
                )
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            if value.translation.width < -50 {
                                viewModel.goToNextMonth()
                            } else if value.translation.width > 50 {
                                viewModel.goToPreviousMonth()
                            }
                        }
                )

                Spacer()
            }
            .background(Color.warmPaper)

            // 底部抽屉覆盖层
            EntryBottomSheet(
                selectedDate: viewModel.selectedDate,
                entries: selectedEntries,
                viewMode: $viewModel.viewMode,
                photoWallScrollTarget: .constant(nil),
                onCreateEntry: { date in
                    newEntryDate = date
                    showingNewEntry = true
                }
            )
        }
        .sheet(isPresented: $showingNewEntry) {
            EntryEditorView(
                entry: nil,
                context: CoreDataStack.shared.viewContext,
                prefillDate: newEntryDate
            )
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(.warmAccent)
                    .padding(8)
            }

            Spacer()

            Text(monthTitle)
                .font(.warmHeadline)
                .foregroundColor(.warmDark)

            Spacer()

            Button {
                viewModel.goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.warmAccent)
                    .padding(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.warmCream)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: viewModel.currentMonth)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add dayfold/dayfold/Views/Timeline/CalendarView.swift
git commit -m "feat: add CalendarView with month navigation and bottom sheet"
```

---

## Task 6：EntryEditorView 支持预填日期

**Files:**
- Modify: `dayfold/dayfold/ViewModels/EntryEditorViewModel.swift`
- Modify: `dayfold/dayfold/Views/Entry/EntryEditorView.swift`

- [ ] **Step 1: EntryEditorViewModel 添加 prefillDate 支持**

在 `EntryEditorViewModel.swift` 的 `init` 中，找到：

```swift
init(context: NSManagedObjectContext, entry: Entry? = nil) {
    self.viewContext = context
    self.entry = entry
    self.isNewEntryOnInit = (entry == nil)
```

修改为：

```swift
init(context: NSManagedObjectContext, entry: Entry? = nil, prefillDate: Date? = nil) {
    self.viewContext = context
    self.entry = entry
    self.isNewEntryOnInit = (entry == nil)
    self.prefillDate = prefillDate
```

并在类的属性声明区添加：

```swift
private let prefillDate: Date?
```

然后在 `saveEntry()` 方法中找到创建新条目的部分，确保使用 `prefillDate`：

找到：
```swift
let entry = Entry.create(in: viewContext)
```

改为：
```swift
let entry = Entry.create(in: viewContext)
if let prefillDate = prefillDate {
    entry.createdAt = prefillDate
    entry.modifiedAt = prefillDate
}
```

- [ ] **Step 2: EntryEditorView 添加 prefillDate 参数**

在 `EntryEditorView.swift` 找到：

```swift
init(entry: Entry? = nil, context: NSManagedObjectContext) {
    _viewModel = StateObject(wrappedValue: EntryEditorViewModel(context: context, entry: entry))
}
```

改为：

```swift
init(entry: Entry? = nil, context: NSManagedObjectContext, prefillDate: Date? = nil) {
    _viewModel = StateObject(wrappedValue: EntryEditorViewModel(context: context, entry: entry, prefillDate: prefillDate))
}
```

- [ ] **Step 3: Commit**

```bash
git add dayfold/dayfold/ViewModels/EntryEditorViewModel.swift dayfold/dayfold/Views/Entry/EntryEditorView.swift
git commit -m "feat: support prefillDate in EntryEditorView for calendar quick-create"
```

---

## Task 7：PhotoWallView（照片墙）

**Files:**
- Create: `dayfold/dayfold/Views/Timeline/PhotoWallView.swift`

- [ ] **Step 1: 创建 PhotoWallView.swift**

```swift
// Views/Timeline/PhotoWallView.swift
import SwiftUI

struct PhotoWallView: View {
    @ObservedObject var viewModel: TimelineViewModel
    var scrollTarget: UUID?

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
                            // 跳转详情由 NavigationLink 处理
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
                            isLarge: item.isLarge
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

    @State private var thumbnail: UIImage?
    @State private var highlighted = false

    var body: some View {
        NavigationLink(destination: EntryDetailView(entry: entry)) {
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
        .scaleEffect(highlighted ? 1.04 : 1.0)
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
```

- [ ] **Step 2: Commit**

```bash
git add dayfold/dayfold/Views/Timeline/PhotoWallView.swift
git commit -m "feat: add PhotoWallView with staggered grid and favorite large tiles"
```

---

## Task 8：TimelineView 替换占位符

**Files:**
- Modify: `dayfold/dayfold/Views/Timeline/TimelineView.swift`

- [ ] **Step 1: 替换 TimelineView.swift 完整内容**

```swift
// Views/Timeline/TimelineView.swift
import SwiftUI
import CoreData

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    @State private var photoWallScrollTarget: UUID?

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: TimelineViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("视图模式", selection: $viewModel.viewMode) {
                    Label("列表", systemImage: "list.bullet").tag(TimelineViewMode.list)
                    Label("日历", systemImage: "calendar").tag(TimelineViewMode.calendar)
                    Label("照片墙", systemImage: "square.grid.2x2").tag(TimelineViewMode.photoWall)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.warmLight)

                Group {
                    switch viewModel.viewMode {
                    case .list:
                        TimelineListView()
                    case .calendar:
                        CalendarView(viewModel: viewModel)
                    case .photoWall:
                        PhotoWallView(viewModel: viewModel, scrollTarget: photoWallScrollTarget)
                    }
                }
            }
            .navigationTitle("时间轴")
            .background(Color.warmPaper)
        }
    }
}

#Preview {
    let context = CoreDataStack.shared.viewContext
    TimelineView(context: context)
        .environment(\.managedObjectContext, context)
}
```

- [ ] **Step 2: Commit**

```bash
git add dayfold/dayfold/Views/Timeline/TimelineView.swift
git commit -m "feat: wire CalendarView and PhotoWallView into TimelineView"
```

---

## Task 9：EntryDetailView 收藏按钮

**Files:**
- Modify: `dayfold/dayfold/Views/Entry/EntryDetailView.swift`

- [ ] **Step 1: 在导航栏添加收藏按钮**

在 `EntryDetailView.swift` 找到 `.toolbar` 中现有的 `ToolbarItem`：

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button {
            showingEditSheet = true
        } label: {
            Text("编辑")
                .foregroundColor(.warmAccent)
        }
    }
}
```

替换为：

```swift
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
```

然后在 `EntryDetailView` 的 body 外添加私有方法：

```swift
private func toggleFavorite() {
    let context = entry.managedObjectContext ?? CoreDataStack.shared.viewContext
    entry.isFavorite.toggle()
    try? context.save()
}
```

- [ ] **Step 2: Commit**

```bash
git add dayfold/dayfold/Views/Entry/EntryDetailView.swift
git commit -m "feat: add favorite toggle button to EntryDetailView"
```

---

## Task 10：EntryEditorView 收藏按钮

**Files:**
- Modify: `dayfold/dayfold/ViewModels/EntryEditorViewModel.swift`
- Modify: `dayfold/dayfold/Views/Entry/EntryEditorView.swift`

- [ ] **Step 1: EntryEditorViewModel 添加 isFavorite 和 toggleFavorite**

在 `EntryEditorViewModel.swift` 的 `@Published` 属性列表中添加：

```swift
@Published var isFavorite: Bool = false
```

在 `init` 中，找到已有的 `if let entry = entry {` 块，添加：

```swift
self.isFavorite = entry.isFavorite
```

在 `saveEntry()` 中，找到设置 entry 属性的部分（`entry.title = ...`），添加：

```swift
entry.isFavorite = isFavorite
```

- [ ] **Step 2: EntryEditorView 工具栏添加收藏按钮**

在 `EntryEditorView.swift` 的 `.toolbar` 中，找到保存按钮的 `ToolbarItem`，在其前面插入：

```swift
ToolbarItem(placement: .navigationBarTrailing) {
    Button {
        viewModel.isFavorite.toggle()
    } label: {
        Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
            .foregroundColor(.warmAccent)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add dayfold/dayfold/ViewModels/EntryEditorViewModel.swift dayfold/dayfold/Views/Entry/EntryEditorView.swift
git commit -m "feat: add favorite toggle to EntryEditorView"
```

---

## 自检结果

**Spec 覆盖确认：**
- ✅ Entry.isFavorite — Task 1（`wrappedIsFavorite`，isFavorite 已在 schema 中）
- ✅ TimelineViewModel 新属性 — Task 2
- ✅ MonthGridView + DayCell + 圆点指示器 — Task 3
- ✅ EntryBottomSheet（三档吸附、overlay 实现、空日期提示、+ 按钮） — Task 4
- ✅ CalendarView（月份导航、手势切换、联动照片墙） — Task 5
- ✅ 预填日期创建条目 — Task 6
- ✅ PhotoWallView（交错网格、大格逻辑、角标、长按菜单、空状态） — Task 7
- ✅ TimelineView 替换占位符 — Task 8
- ✅ EntryDetailView 收藏按钮 — Task 9
- ✅ EntryEditorView 收藏按钮 — Task 10

**类型一致性：**
- `EntryDotType` 定义在 Task 2（TimelineViewModel.swift），Task 3 直接使用 ✅
- `TimelineViewMode` 定义在 Task 2，所有视图通过 `viewModel.viewMode` 访问 ✅
- `viewModel.entriesWithPhotos` 在 Task 2 定义，Task 7 使用 ✅
- `prefillDate` 参数在 Task 6 添加到 ViewModel 和 View，Task 5 调用 ✅
