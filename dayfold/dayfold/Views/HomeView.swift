// Views/HomeView.swift
import SwiftUI
import CoreData

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.theme) private var theme
    let context: NSManagedObjectContext
    @Binding var isListMode: Bool
    var onNewEntry: () -> Void

    @State private var currentIndex: Int = 0
    @State private var confirmDelete = false
    @State private var showDetail = false
    @State private var editingNotebook: Notebook?
    /// 当前本子的镜像 + @ObservedObject 订阅，确保 Core Data 字段变化（name / coverStyle / hasPassword）
    /// 触发 HomeView 重绘。`currentNotebook` 计算属性本身不触发 SwiftUI 订阅。
    @State private var observedNotebook: Notebook?
    @Namespace private var coverNamespace

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Notebook.sortOrder, ascending: true),
                          NSSortDescriptor(keyPath: \Notebook.createdAt, ascending: true)],
        animation: .default
    ) private var notebooks: FetchedResults<Notebook>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Entry.createdAt, ascending: false)],
        animation: .default
    ) private var entries: FetchedResults<Entry>

    var currentNotebook: Notebook? {
        guard notebooks.indices.contains(currentIndex) else { return nil }
        return notebooks[currentIndex]
    }

    var entryCount: Int { entries.count }
    var latestDate: String {
        guard let date = entries.first?.createdAt else { return "—" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd"
        return fmt.string(from: date)
    }

    var body: some View {
        ZStack {
            theme.backgroundTertiary.ignoresSafeArea()

            if isListMode {
                listModeView
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                coverModeView
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: isListMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: confirmDelete)
        .fullScreenCover(isPresented: $showDetail) {
            if let nb = currentNotebook {
                NotebookDetailView(
                    notebook: nb,
                    onNewEntry: onNewEntry,
                    isPresented: $showDetail
                )
                .environment(\.managedObjectContext, context)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                    removal: .scale(scale: 0.85).combined(with: .opacity)
                ))
            }
        }
        .sheet(item: $editingNotebook) { nb in
            NotebookSettingsSheet(notebook: nb)
                .environment(\.managedObjectContext, context)
        }
        // 切换 notebook → 同步到 observedNotebook 触发订阅
        .onChange(of: currentIndex) { _ in
            observedNotebook = currentNotebook
        }
        .onAppear {
            observedNotebook = currentNotebook
        }
    }

    // MARK: - 封面翻页模式

    private var coverModeView: some View {
        VStack(spacing: 0) {
            // 标题区 — NotebookTitleHeader 内部持有 @ObservedObject,
            // Notebook 字段(name/coverStyle 等)变更触发该 view 重绘,无需等 currentIndex 切换。
            VStack(spacing: 6) {
                if let nb = observedNotebook ?? currentNotebook {
                    NotebookTitleHeader(notebook: nb)
                } else {
                    Text("DAYFOLD")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(theme.textPrimary)
                        .tracking(3)
                }
                Text("\(latestDate) / \(entryCount) entries")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.top, 100)
            .frame(height: 134)

            Spacer()

            // 笔记本翻页区
            if notebooks.isEmpty {
                emptyState
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(notebooks.enumerated()), id: \.element.objectID) { idx, nb in
                        NotebookCoverView(
                            notebook: nb,
                            editingNotebook: $editingNotebook
                        ) {
                            currentIndex = idx
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                                showDetail = true
                            }
                        }
                        .frame(width: 240, height: 340)
                        .tag(idx)
                        .notebookPageTurn(idx: idx, currentIndex: $currentIndex)   // 新增
                        .padding(.horizontal, 40)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 380)
            }

            Spacer()

            // 页码指示器
            if notebooks.count > 1 {
                PageIndicator(count: notebooks.count, current: currentIndex)
                    .padding(.bottom, 16)
            }

            // 底部按钮
            if confirmDelete {
                HStack(spacing: 20) {
                    CircleActionButton(icon: "xmark", bgColor: theme.surfacePaper, iconColor: theme.surfacePaperInk) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { confirmDelete = false }
                    }
                    CircleActionButton(icon: "checkmark", bgColor: theme.accentPrimary, iconColor: .white) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            deleteCurrentNotebook()
                            confirmDelete = false
                        }
                    }
                }
                .padding(.bottom, 48)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                HStack(spacing: 20) {
                    CircleActionButton(icon: "plus", bgColor: theme.surfacePaper, iconColor: theme.surfacePaperInk) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { addNotebook() }
                    }
                    CircleActionButton(icon: "trash", bgColor: theme.surfacePaper, iconColor: theme.surfacePaperInk) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { confirmDelete = true }
                    }
                }
                .padding(.bottom, 48)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
    }

    // MARK: - 列表模式

    private var listModeView: some View {
        VStack(spacing: 0) {
            // 顶部占位（与封面模式对齐）
            Spacer().frame(height: 100)

            if notebooks.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(notebooks.enumerated()), id: \.element.objectID) { idx, nb in
                            NotebookListRow(notebook: nb, isSelected: idx == currentIndex) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    currentIndex = idx
                                }
                            }
                            if idx < notebooks.count - 1 {
                                Divider()
                                    .background(theme.dividerPrimary)
                                    .padding(.leading, 80)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }

            Spacer()

            // 列表模式底部：只有 + 按钮，居中
            CircleActionButton(icon: "plus", bgColor: theme.surfacePaper, iconColor: theme.surfacePaperInk) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { addNotebook() }
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - 列表行

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(theme.textTertiary)
            Text("暂无笔记本")
                .font(.system(size: 16))
                .foregroundColor(theme.textTertiary)
        }
        .frame(height: 380)
    }

    // MARK: - 操作

    private func addNotebook() {
        let styles = NotebookCoverStyle.allCases
        let usedStyles = notebooks.map { Int($0.coverStyleRaw) }
        let nextStyle = styles.first(where: { !usedStyles.contains($0.rawValue) }) ?? styles[notebooks.count % styles.count]
        let nb = Notebook.create(name: "UNTITLED", style: nextStyle, in: context)
        nb.sortOrder = Int32(notebooks.count)
        try? CoreDataStack.shared.save()
        currentIndex = notebooks.count - 1
    }

    private func deleteCurrentNotebook() {
        guard notebooks.indices.contains(currentIndex) else { return }
        let nb = notebooks[currentIndex]
        nb.deleteWithEntriesToTrash(in: context)
        try? CoreDataStack.shared.save()
        if currentIndex >= notebooks.count {
            currentIndex = max(0, notebooks.count - 1)
        }
    }
}

// MARK: - 笔记本标题区(实时响应 name 变更)

/// 仅持有一个 `@ObservedObject var notebook: Notebook`,让 Notebook 字段(name/coverStyle)
/// 变更触发本 view 重绘。
///
/// 为什么不直接在 HomeView.body 读 `currentNotebook?.wrappedName`?
/// `currentNotebook` 是计算属性,SwiftUI 不会订阅;且 `Notebook` 是 NSManagedObject,
/// 必须显式 `@ObservedObject` 才能让 KVO 变更转 SwiftUI 重绘。
private struct NotebookTitleHeader: View {
    @Environment(\.theme) private var theme
    @ObservedObject var notebook: Notebook

    var body: some View {
        Text(notebook.wrappedName)
            .font(.system(size: 26, weight: .black))
            .foregroundColor(theme.textPrimary)
            .tracking(3)
    }
}

// MARK: - 笔记本封面视图

struct NotebookCoverView: View {
    @Environment(\.theme) private var theme
    @ObservedObject var notebook: Notebook
    @Binding var editingNotebook: Notebook?
    var onOpenDetail: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let spineW = w * 0.26

            ZStack(alignment: .leading) {
                // 主封面
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.surfacePaper)
                    .overlay(
                        coverForeground
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
                    .overlay(
                        // 缝线
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .padding(9)
                    )

                // 书脊
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                notebook.coverStyle.spineColor.opacity(0.95),
                                notebook.coverStyle.spineColor,
                                notebook.coverStyle.spineColor.opacity(0.85),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: spineW)
                    .clipShape(RoundedCornerShape(radius: 16, corners: [.topLeft, .bottomLeft]))
                    .overlay(
                        // 书脊高光线
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0), Color.white.opacity(0.15), Color.white.opacity(0)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(width: 1.5)
                            .offset(x: spineW * 0.6),
                        alignment: .leading
                    )

                // 书脊→封面交界阴影
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.black.opacity(0.38), Color.clear],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: 22)
                    .offset(x: spineW - 4)

                // ℹ️ 徽章 — Button 独立可点
                Button {
                    editingNotebook = notebook
                } label: {
                    ZStack {
                        Circle()
                            .fill(theme.surfacePaper)
                            .frame(width: 30, height: 30)
                            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                        Text("i")
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .italic()
                            .foregroundColor(theme.surfacePaperInk)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 14)
                .padding(.trailing, 14)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                // Button 会优先消费 i 徽章的点击；这里的 onTapGesture 只响应 cover 主体
                onOpenDetail()
            }
        }
    }

    /// 封面前景图层：Custom Skin 优先；否则显示 SKIN 图案。
    @ViewBuilder
    private var coverForeground: some View {
        if let img = notebook.customSkinImage {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            CoverPatternView(style: notebook.coverStyle)
        }
    }
}

// MARK: - 封面图案

private struct CoverPatternView: View {
    @Environment(\.theme) private var theme
    let style: NotebookCoverStyle

    var body: some View {
        switch style {
        case .chevronTeal:   ChevronPattern()
        case .triangleRed:   TrianglePattern()
        case .stripesBlack:  StripesPattern()
        case .leatherBrown:  LeatherPattern()
        case .diagonalGray:  DiagonalPattern()
        }
    }
}

private struct ChevronPattern: View {
    @Environment(\.theme) private var theme
    var body: some View {
        ZStack {
            theme.controlInactive
            GeometryReader { geo in
                let rows = 10
                let h = geo.size.height / CGFloat(rows)
                ForEach(0..<rows, id: \.self) { row in
                    ChevronShape(row: row, height: h)
                        .fill(Color(hex: row % 2 == 0 ? "4ABBC4" : "6DD4DC").opacity(0.6))
                        .offset(y: CGFloat(row) * h)
                }
            }
        }
    }
}

private struct ChevronShape: Shape {
    let row: Int
    let height: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mid = rect.midX
        let h = height
        p.move(to: CGPoint(x: 0, y: h * 0.5))
        p.addLine(to: CGPoint(x: mid, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: h * 0.5))
        p.addLine(to: CGPoint(x: rect.maxX, y: h))
        p.addLine(to: CGPoint(x: mid, y: h * 0.5))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

private struct TrianglePattern: View {
    @Environment(\.theme) private var theme
    var body: some View {
        ZStack {
            theme.surfacePaper
            GeometryReader { geo in
                let cols = 5, rows = 8
                let tw = geo.size.width / CGFloat(cols)
                let th = geo.size.height / CGFloat(rows)
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        TriangleShape()
                            .fill(triangleColor(row: row, col: col))
                            .frame(width: tw, height: th)
                            .offset(x: CGFloat(col) * tw, y: CGFloat(row) * th)
                    }
                }
            }
        }
    }
    func triangleColor(row: Int, col: Int) -> Color {
        let colors = [Color(hex: "C04030"), Color(hex: "905535"), Color(hex: "B0A090"), Color(hex: "D0C8B8")]
        return colors[(row + col) % colors.count].opacity(0.85)
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct StripesPattern: View {
    @Environment(\.theme) private var theme
    var body: some View {
        ZStack {
            theme.surfacePaper
            GeometryReader { geo in
                let count = 8
                let w = geo.size.width / CGFloat(count)
                ForEach(0..<count, id: \.self) { i in
                    if i % 2 == 0 {
                        Rectangle()
                            .fill(theme.shadowOverlay.opacity(0.85))
                            .frame(width: w * 0.6)
                            .offset(x: CGFloat(i) * w + w * 0.2)
                    }
                }
            }
        }
    }
}

private struct LeatherPattern: View {
    @Environment(\.theme) private var theme
    var body: some View {
        LinearGradient(
            colors: [theme.surfaceLeather, theme.surfaceLeather, theme.surfaceLeather],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.clear, Color.black.opacity(0.08)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

private struct DiagonalPattern: View {
    @Environment(\.theme) private var theme
    var body: some View {
        ZStack {
            theme.surfacePaper
            GeometryReader { geo in
                let count = 6
                let spacing = geo.size.width / CGFloat(count)
                ForEach(0..<count * 2, id: \.self) { i in
                    Path { p in
                        let x = CGFloat(i) * spacing - geo.size.height
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x + geo.size.height, y: geo.size.height))
                    }
                    .stroke(theme.shadowOverlay.opacity(0.75), lineWidth: i % 3 == 0 ? 3 : 1.2)
                }
            }
        }
    }
}

// MARK: - 页码指示器

private struct PageIndicator: View {
    @Environment(\.theme) private var theme
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? theme.accentPrimary : theme.textTertiary)
                    .frame(width: i == current ? 24 : 14, height: 3)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
    }
}

// MARK: - 圆形按钮

private struct CircleActionButton: View {
    @Environment(\.theme) private var theme
    let icon: String
    let bgColor: Color
    let iconColor: Color
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(bgColor)
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isPressed { withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) { isPressed = true } } }
                .onEnded { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false } }
        )
    }
}

// MARK: - 圆角辅助

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

// MARK: - 笔记本列表行

struct NotebookListRow: View {
    @Environment(\.theme) private var theme
    @ObservedObject var notebook: Notebook
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 圆形封面缩略图
                ZStack {
                    Circle()
                        .fill(theme.backgroundTertiary)
                        .frame(width: 52, height: 52)
                    Circle()
                        .clipShape(Circle())
                        .frame(width: 52, height: 52)
                        .overlay(
                            CoverPatternView(style: notebook.coverStyle)
                                .clipShape(Circle())
                        )
                }
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // 文字
                VStack(alignment: .leading, spacing: 3) {
                    Text(notebook.wrappedName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSelected ? theme.accentPrimary : theme.textPrimary)
                    Text("0 PHOTOS")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(theme.textTertiary)
                        .tracking(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.accentPrimary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isPressed ? theme.backgroundPressed : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isPressed { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    let context = CoreDataStack.shared.viewContext
    _ = Notebook.create(name: "预览", style: .chevronTeal, in: context)
    return HomeView(context: context, isListMode: .constant(false), onNewEntry: {})
        .environment(\.managedObjectContext, context)
}
