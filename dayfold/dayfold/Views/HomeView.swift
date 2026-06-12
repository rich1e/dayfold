// Views/HomeView.swift
import SwiftUI
import CoreData

// MARK: - 笔记本数据模型

struct Notebook: Identifiable {
    let id: UUID
    var name: String
    var coverStyle: CoverStyle
    var createdAt: Date

    enum CoverStyle: Int, CaseIterable {
        case chevronTeal, triangleRed, stripesBlack, leatherBrown, diagonalGray

        var spineColor: Color {
            switch self {
            case .chevronTeal:   return Color(hex: "8A8A90")
            case .triangleRed:   return Color(hex: "C04030")
            case .stripesBlack:  return Color(hex: "303035")
            case .leatherBrown:  return Color(hex: "2C1A0A")
            case .diagonalGray:  return Color(hex: "606065")
            }
        }
    }

    static func make(style: CoverStyle? = nil) -> Notebook {
        let styles = CoverStyle.allCases
        let s = style ?? styles[Int.random(in: 0..<styles.count)]
        return Notebook(id: UUID(), name: "UNTITLED", coverStyle: s, createdAt: Date())
    }
}

// MARK: - HomeView

struct HomeView: View {
    let context: NSManagedObjectContext
    var onNewEntry: () -> Void

    @State private var notebooks: [Notebook] = [Notebook.make(style: .chevronTeal)]
    @State private var currentIndex: Int = 0
    @State private var confirmDelete = false

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
            Color(hex: "2A2A30").ignoresSafeArea()

            VStack(spacing: 0) {
                // 标题区
                VStack(spacing: 6) {
                    Text(currentNotebook?.name ?? "DAYFOLD")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(Color(hex: "D4A574"))
                        .tracking(3)
                        .animation(.easeOut(duration: 0.2), value: currentIndex)

                    Text("\(latestDate) / \(entryCount) entries")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: "7A7A88"))
                }
                .padding(.top, 28)
                .frame(height: 72)

                Spacer()

                // 笔记本翻页区
                if notebooks.isEmpty {
                    emptyState
                } else {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(notebooks.enumerated()), id: \.element.id) { idx, nb in
                            NotebookCoverView(notebook: nb)
                                .frame(width: 240, height: 340)
                                .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 16)
                                .tag(idx)
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
                        CircleActionButton(icon: "xmark", bgColor: Color(hex: "E8D5B8"), iconColor: Color(hex: "4A3828")) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                confirmDelete = false
                            }
                        }
                        CircleActionButton(icon: "checkmark", bgColor: Color(hex: "E05A3A"), iconColor: .white) {
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
                        CircleActionButton(icon: "plus", bgColor: Color(hex: "E8D5B8"), iconColor: Color(hex: "4A3828")) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                addNotebook()
                            }
                        }
                        CircleActionButton(icon: "trash", bgColor: Color(hex: "D0C8BA"), iconColor: Color(hex: "4A3828")) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                confirmDelete = true
                            }
                        }
                    }
                    .padding(.bottom, 48)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: confirmDelete)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "5A5A65"))
            Text("暂无笔记本")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "7A7A88"))
        }
        .frame(height: 380)
    }

    // MARK: - 操作

    private func addNotebook() {
        let styles = Notebook.CoverStyle.allCases
        let usedStyles = notebooks.map(\.coverStyle.rawValue)
        let nextStyle = styles.first(where: { !usedStyles.contains($0.rawValue) }) ?? styles[notebooks.count % styles.count]
        let nb = Notebook.make(style: nextStyle)
        notebooks.append(nb)
        currentIndex = notebooks.count - 1
    }

    private func deleteCurrentNotebook() {
        guard notebooks.indices.contains(currentIndex) else { return }
        notebooks.remove(at: currentIndex)
        if currentIndex >= notebooks.count {
            currentIndex = max(0, notebooks.count - 1)
        }
    }
}

// MARK: - 笔记本封面视图

struct NotebookCoverView: View {
    let notebook: Notebook

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let spineW = w * 0.26

            ZStack(alignment: .leading) {
                // 主封面
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "F0EDE5"))
                    .overlay(
                        CoverPatternView(style: notebook.coverStyle)
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

                // ℹ️ 徽章
                ZStack {
                    Circle()
                        .fill(Color(hex: "F0EAE0"))
                        .frame(width: 30, height: 30)
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                    Text("i")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .italic()
                        .foregroundColor(Color(hex: "4A3020"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 14)
                .padding(.trailing, 14)
            }
        }
    }
}

// MARK: - 封面图案

private struct CoverPatternView: View {
    let style: Notebook.CoverStyle

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
    var body: some View {
        ZStack {
            Color(hex: "5BC8D0")
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
    var body: some View {
        ZStack {
            Color(hex: "E8E0D0")
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
    var body: some View {
        ZStack {
            Color(hex: "E8E5E0")
            GeometryReader { geo in
                let count = 8
                let w = geo.size.width / CGFloat(count)
                ForEach(0..<count, id: \.self) { i in
                    if i % 2 == 0 {
                        Rectangle()
                            .fill(Color(hex: "1A1A20").opacity(0.85))
                            .frame(width: w * 0.6)
                            .offset(x: CGFloat(i) * w + w * 0.2)
                    }
                }
            }
        }
    }
}

private struct LeatherPattern: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: "C17A3A"), Color(hex: "A85E20"), Color(hex: "C07030")],
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
    var body: some View {
        ZStack {
            Color(hex: "E8E5E0")
            GeometryReader { geo in
                let count = 6
                let spacing = geo.size.width / CGFloat(count)
                ForEach(0..<count * 2, id: \.self) { i in
                    Path { p in
                        let x = CGFloat(i) * spacing - geo.size.height
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x + geo.size.height, y: geo.size.height))
                    }
                    .stroke(Color(hex: "1A1A20").opacity(0.75), lineWidth: i % 3 == 0 ? 3 : 1.2)
                }
            }
        }
    }
}

// MARK: - 页码指示器

private struct PageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color(hex: "E05A3A") : Color(hex: "5A5A65"))
                    .frame(width: i == current ? 24 : 14, height: 3)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: current)
            }
        }
    }
}

// MARK: - 圆形按钮

private struct CircleActionButton: View {
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

#Preview {
    HomeView(context: CoreDataStack.shared.viewContext, onNewEntry: {})
}
