// Views/Entry/TrashView.swift
import SwiftUI
import CoreData

struct TrashView: View {
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.deletedAt, order: .reverse)],
        predicate: NSPredicate(format: "deletedAt != nil"),
        animation: .default
    )
    private var trashedEntries: FetchedResults<Entry>

    @StateObject private var viewModel: EntryListViewModel

    // 选择模式
    @State private var isSelectionMode = false
    @State private var selectedIDs: Set<NSManagedObjectID> = []

    // 二次确认
    @State private var showingClearAllAlert = false
    @State private var showingBatchDeleteAlert = false
    @State private var pendingSingleDelete: Entry?

    // Toast 反馈
    @State private var toast: ToastMessage?

    init() {
        _viewModel = StateObject(
            wrappedValue: EntryListViewModel(context: CoreDataStack.shared.viewContext)
        )
    }

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                if isSelectionMode {
                    selectionTopBar
                } else {
                    normalTopBar
                }

                if trashedEntries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
        }
        .toast($toast)
        .safeAreaInset(edge: .bottom) {
            if isSelectionMode {
                selectionBottomBar
            }
        }
        .alert("删除全部", isPresented: $showingClearAllAlert) {
            Button("删除 \(trashedEntries.count) 个条目", role: .destructive) {
                clearAll()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("\(trashedEntries.count) 个条目将删除。这是永久操作,无法撤销。")
        }
        .alert("删除选中", isPresented: $showingBatchDeleteAlert) {
            Button("删除 \(selectedIDs.count) 个条目", role: .destructive) {
                batchDelete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("\(selectedIDs.count) 个条目将删除。这是永久操作,无法撤销。")
        }
        .alert("确认删除", isPresented: Binding(
            get: { pendingSingleDelete != nil },
            set: { if !$0 { pendingSingleDelete = nil } }
        )) {
            Button("彻底删除", role: .destructive) {
                if let entry = pendingSingleDelete {
                    singleDelete(entry)
                }
            }
            Button("取消", role: .cancel) {
                pendingSingleDelete = nil
            }
        } message: {
            Text("此条目将从回收箱永久删除,无法恢复。")
        }
    }

    // MARK: - 顶部栏(常态)

    private var normalTopBar: some View {
        HStack {
            Button {
                showingClearAllAlert = true
            } label: {
                Text("全部删除")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.accentDestructive)
                    .cornerRadius(20)
            }
            .disabled(trashedEntries.isEmpty)
            .opacity(trashedEntries.isEmpty ? 0.4 : 1)

            Spacer()

            Text("回收箱")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSelectionMode = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(theme.accentPrimary)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textOnAccent)
                }
            }
            .disabled(trashedEntries.isEmpty)
            .opacity(trashedEntries.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.backgroundTertiary)
    }

    // MARK: - 顶部栏(选择模式)

    private var selectionTopBar: some View {
        HStack {
            Button {
                toggleSelectAll()
            } label: {
                Text(isAllSelected ? "取消全选" : "全选")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(theme.accentPrimary)
            }

            Spacer()

            Text("回收箱")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSelectionMode = false
                    selectedIDs.removeAll()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(theme.backgroundElevated)
                        .frame(width: 36, height: 36)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.backgroundTertiary)
    }

    // MARK: - 底部工具栏(选择模式)

    private var selectionBottomBar: some View {
        let disabled = selectedIDs.isEmpty
        return HStack(spacing: 12) {
            Button {
                batchRestore()
            } label: {
                Text("恢复")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(disabled ? theme.textTertiary : theme.textPrimary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(disabled ? theme.backgroundElevated.opacity(0.5) : theme.backgroundElevated)
                    )
            }
            .disabled(disabled)

            Spacer()

            Text("已选中 \(selectedIDs.count) 个")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)

            Spacer()

            Button {
                showingBatchDeleteAlert = true
            } label: {
                Text("删除")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(disabled ? .white.opacity(0.5) : .white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(disabled ? theme.accentDestructive.opacity(0.4) : theme.accentDestructive)
                    )
            }
            .disabled(disabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.backgroundSecondary)
    }

    // MARK: - 列表

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedEntries, id: \.dayKey) { group in
                    rows(for: group)
                }
            }
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func rows(for group: DayGroup) -> some View {
        ForEach(Array(group.entries.enumerated()), id: \.element.objectID) { idx, entry in
            rowView(group: group, idx: idx, entry: entry)
        }
    }

    private func rowView(group: DayGroup, idx: Int, entry: Entry) -> some View {
        TrashEntryRow(
            entry: entry,
            weekday: group.weekday,
            day: group.day,
            isFirstInGroup: idx == 0,
            isLastInGroup: idx == group.entries.count - 1,
            isSelectionMode: isSelectionMode,
            isSelected: selectedIDs.contains(entry.objectID),
            onTapRow: { handleRowTap(entry) },
            onRestore: { restore(entry) },
            onDelete: { pendingSingleDelete = entry },
            onSelectButton: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSelectionMode = true
                    selectedIDs = [entry.objectID]
                }
            }
        )
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "trash")
                .font(.system(size: 52))
                .foregroundColor(theme.textTertiary)
            Text("回收箱为空")
                .font(.system(size: 16))
                .foregroundColor(theme.textSecondary)
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

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let weekdayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEEE"
        return f
    }()

    private static let dayNumFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private var groupedEntries: [DayGroup] {
        var result: [DayGroup] = []
        var current: (key: String, list: [Entry])?
        for entry in trashedEntries {
            let date = entry.deletedAt ?? Date()
            let key = Self.dayFmt.string(from: date)
            if current?.key == key {
                current!.list.append(entry)
            } else {
                if let c = current {
                    let d = Self.dayFmt.date(from: c.key) ?? Date()
                    result.append(DayGroup(
                        dayKey: c.key,
                        weekday: Self.weekdayFmt.string(from: d),
                        day: Self.dayNumFmt.string(from: d),
                        entries: c.list
                    ))
                }
                current = (key, [entry])
            }
        }
        if let c = current {
            let d = Self.dayFmt.date(from: c.key) ?? Date()
            result.append(DayGroup(
                dayKey: c.key,
                weekday: Self.weekdayFmt.string(from: d),
                day: Self.dayNumFmt.string(from: d),
                entries: c.list
            ))
        }
        return result
    }

    // MARK: - 状态判断

    private var isAllSelected: Bool {
        guard !trashedEntries.isEmpty else { return false }
        return selectedIDs.count == trashedEntries.count
    }

    // MARK: - 交互

    private func handleRowTap(_ entry: Entry) {
        guard isSelectionMode else { return }
        toggleSelect(entry)
    }

    private func toggleSelect(_ entry: Entry) {
        let id = entry.objectID
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func toggleSelectAll() {
        if isAllSelected {
            selectedIDs.removeAll()
        } else {
            selectedIDs = Set(trashedEntries.map(\.objectID))
        }
    }

    private func restore(_ entry: Entry) {
        viewModel.restore([entry])
        toast = ToastMessage(text: "1 个条目已恢复为日记")
    }

    private func batchRestore() {
        let entries = selectedEntries()
        guard !entries.isEmpty else { return }
        viewModel.restore(entries)
        let count = entries.count
        withAnimation(.easeInOut(duration: 0.25)) {
            isSelectionMode = false
            selectedIDs.removeAll()
        }
        toast = ToastMessage(text: "\(count) 个条目已恢复为日记")
    }

    private func singleDelete(_ entry: Entry) {
        viewModel.permanentlyDelete([entry], context: viewContext)
        pendingSingleDelete = nil
    }

    private func batchDelete() {
        let entries = selectedEntries()
        guard !entries.isEmpty else { return }
        viewModel.permanentlyDelete(entries, context: viewContext)
        let count = entries.count
        withAnimation(.easeInOut(duration: 0.25)) {
            isSelectionMode = false
            selectedIDs.removeAll()
        }
        toast = ToastMessage(text: "\(count) 个条目已彻底删除")
    }

    private func clearAll() {
        let entries = Array(trashedEntries)
        viewModel.permanentlyDelete(entries, context: viewContext)
        let count = entries.count
        if count > 0 {
            toast = ToastMessage(text: "\(count) 个条目已彻底删除")
        }
    }

    private func selectedEntries() -> [Entry] {
        trashedEntries.filter { selectedIDs.contains($0.objectID) }
    }
}

// MARK: - 条目行(右滑露出 3 个胶囊按钮)

/// 整行(含左侧日期列)跟随手指左滑,右侧露出 3 个圆角矩形胶囊按钮。
/// 完全复刻 iOS Reminders/Mail 的 swipeActions 视觉:
/// - 手指滑动 → 内容层实时跟随
/// - 松手时 iOS 风格的硬吸附(滑过阈值才完全展开,否则回弹)
/// - 展开后日期列与文字一起停在按钮左侧,文字保持原宽不被压缩
/// - 选择模式下拖拽手势禁用,只接受点击勾选
private struct TrashEntryRow: View {
    @Environment(\.theme) private var theme
    @ObservedObject var entry: Entry
    let weekday: String
    let day: String
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
    var isSelectionMode: Bool
    var isSelected: Bool
    var onTapRow: () -> Void
    var onRestore: () -> Void
    var onDelete: () -> Void
    var onSelectButton: () -> Void

    /// 拖拽偏移(负值表示行内容向左滑)
    @State private var dragOffset: CGFloat = 0

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// 操作胶囊区域占用的总宽度(右滑出的 3 个按钮)
    private static let actionAreaWidth: CGFloat = 240

    /// 触发"完全展开"的拖拽阈值(超过此值手势结束时吸到 -actionAreaWidth,否则回弹)
    private static let revealThreshold: CGFloat = 80

    /// iOS 原生 swipeActions 风格:硬吸附 + 略带回弹
    private static let snapAnimation: Animation = .interactiveSpring(response: 0.28, dampingFraction: 1.0, blendDuration: 0)

    private var timeString: String {
        Self.timeFmt.string(from: entry.deletedAt ?? Date())
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

    // MARK: 行内容层(含左侧日期列)

    private var rowContent: some View {
        // 让"日期列"和"主内容"垂直居中于行高,使行顶/行底到首/末行文字距离相等。
        HStack(alignment: .center, spacing: 0) {
            // 最左:checkbox(仅选择模式)
            if isSelectionMode {
                checkbox
                    .frame(width: 28, height: 28)
                    .padding(.leading, 16)
                    .padding(.trailing, 8)
            }

            // 日期列
            VStack(alignment: .leading, spacing: 2) {
                Text(weekday)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
                Text(day)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
            }
            .frame(width: 44, alignment: .leading)
            .padding(.leading, isSelectionMode ? 0 : 16)
            .padding(.trailing, 12)

            // 主内容
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.notebook?.wrappedName ?? "日记本")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.controlInactive)
                    Text(meta)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 60)
        .background(isSelected ? theme.highlightOverlay : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onTapRow() }
    }

    // MARK: 操作胶囊层(占据右侧 240pt,默认铺在屏外)

    private var actionLayer: some View {
        HStack(spacing: 8) {
            actionPill(title: "删除", background: theme.accentDestructive, foreground: .white, action: {
                collapse()
                onDelete()
            })
            actionPill(title: "选取", background: theme.backgroundPressed, foreground: theme.textPrimary, action: {
                collapse()
                onSelectButton()
            })
            actionPill(title: "恢复", background: theme.accentSuccess, foreground: .white, action: {
                collapse()
                onRestore()
            })
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(width: Self.actionAreaWidth)
    }

    private func actionPill(title: String, background: Color, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: Self.pillHeight)
                .background(RoundedRectangle(cornerRadius: 10).fill(background))
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 胶囊按钮高度(固定值,不随行高变化,避免被截断)
    private static let pillHeight: CGFloat = 44

    private var checkbox: some View {
        ZStack {
            // 未选中:空心圆
            Circle()
                .strokeBorder(
                    isSelected ? Color.clear : theme.textTertiary.opacity(0.6),
                    lineWidth: 1.5
                )
                .frame(width: 26, height: 26)
                .opacity(isSelected ? 0 : 1)

            // 选中:蓝填充 + 白对勾
            if isSelected {
                Circle()
                    .fill(theme.accentPrimary)
                    .frame(width: 26, height: 26)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textOnAccent)
            }
        }
    }

    var body: some View {
        // 行内容层:跟随 dragOffset 左滑(默认位置 0,完全展开时 -actionAreaWidth)
        // 操作胶囊层:默认完全隐藏在屏外右侧,跟随 dragOffset 滑入
        // 用 GeometryReader 测量行实际宽度,把 actionLayer 起始位置定在 rowWidth(屏外)
        GeometryReader { geo in
            let rowWidth = geo.size.width
            ZStack(alignment: .leading) {
                // 行内容(默认贴左)
                rowContent
                    .frame(width: rowWidth, alignment: .leading)
                    .offset(x: dragOffset)

                // 操作胶囊:默认 offset 到行右侧外侧(屏外)
                actionLayer
                    .offset(x: rowWidth + dragOffset)
            }
        }
        .frame(minHeight: 60)
        .clipped()
        .gesture(swipeGesture)
    }

    // MARK: 手势

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard !isSelectionMode else { return }
                let tx = value.translation.width
                if tx < 0 {
                    // 向左滑:跟随手指,上限 -actionAreaWidth
                    dragOffset = max(tx, -Self.actionAreaWidth)
                } else if dragOffset < 0 {
                    // 已经展开后向右滑回,但不能越过 0
                    dragOffset = min(0, dragOffset + tx)
                }
            }
            .onEnded { _ in
                guard !isSelectionMode else { return }
                withAnimation(Self.snapAnimation) {
                    if -dragOffset > Self.revealThreshold {
                        dragOffset = -Self.actionAreaWidth
                    } else {
                        dragOffset = 0
                    }
                }
            }
    }

    private func collapse() {
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = 0
        }
    }
}

#Preview {
    TrashView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
