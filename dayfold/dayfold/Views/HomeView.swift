// Views/HomeView.swift
import SwiftUI
import CoreData

struct HomeView: View {
    let context: NSManagedObjectContext
    var onNewEntry: () -> Void

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Entry.createdAt, ascending: false)],
        animation: .default
    ) private var entries: FetchedResults<Entry>

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
                    Text("DAYFOLD")
                        .font(.system(size: 28, weight: .black, design: .default))
                        .foregroundColor(Color(hex: "D4A574"))
                        .tracking(4)

                    Text("\(latestDate) / \(entryCount) entries")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: "7A7A88"))
                }
                .padding(.top, 32)

                Spacer()

                // 皮革笔记本封面
                LeatherNotebookView()
                    .frame(width: 280, height: 380)
                    .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 20)

                Spacer()

                // 底部按钮
                HStack(spacing: 20) {
                    CircleActionButton(icon: "plus", bgColor: Color(hex: "E8D5B8")) {
                        onNewEntry()
                    }
                    CircleActionButton(icon: "trash", bgColor: Color(hex: "D0C8BA")) {
                        // 删除操作占位
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - 皮革笔记本封面

private struct LeatherNotebookView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let spineW = w * 0.28

            ZStack(alignment: .leading) {
                // 主封面（橙棕皮革）
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "C17A3A"),
                                Color(hex: "B86C2A"),
                                Color(hex: "A85E20"),
                                Color(hex: "C07030"),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // 皮革纹理噪点层
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.06),
                                        Color.clear,
                                        Color.black.opacity(0.08),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        // 缝线边框
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                Color(hex: "8B4A15").opacity(0.5),
                                style: StrokeStyle(lineWidth: 1.2, dash: [6, 4])
                            )
                            .padding(10)
                    )
                    // 右侧高光
                    .overlay(
                        HStack {
                            Spacer()
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.0), Color.white.opacity(0.07)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: w * 0.3)
                                .cornerRadius(18)
                        }
                    )

                // 书脊（深棕色）
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "1E1208"),
                                    Color(hex: "2C1A0A"),
                                    Color(hex: "3A2010"),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: spineW + 10)

                    // 书脊右侧高光线
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.0), Color.white.opacity(0.12), Color.white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2)
                        .offset(x: spineW * 0.45)
                }
                .frame(width: spineW)
                .clipShape(
                    RoundedCornerShape(radius: 18, corners: [.topLeft, .bottomLeft])
                )

                // 书脊与封面交界阴影
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.45), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 28)
                    .offset(x: spineW - 4)

                // 右侧金属钉 + ℹ️ 按钮
                VStack(spacing: 16) {
                    // ℹ️ 徽章
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F0EAE0"))
                            .frame(width: 34, height: 34)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        Text("i")
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .italic()
                            .foregroundColor(Color(hex: "4A3020"))
                    }

                    Spacer().frame(height: 8)

                    // 金属钉 1
                    MetalStudView()
                    // 金属钉 2
                    MetalStudView()
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, h * 0.12)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 18)
            }
        }
    }
}

private struct MetalStudView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "D4A84B"),
                            Color(hex: "8B6914"),
                            Color(hex: "6B4F10"),
                        ],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: 14
                    )
                )
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)

            // 高光
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 8, height: 8)
                .offset(x: -3, y: -3)
        }
    }
}

// MARK: - 圆形操作按钮

private struct CircleActionButton: View {
    let icon: String
    let bgColor: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(bgColor)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(hex: "4A3828"))
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) { isPressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false }
                }
        )
    }
}

// MARK: - 圆角辅助

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    HomeView(context: CoreDataStack.shared.viewContext, onNewEntry: {})
}
