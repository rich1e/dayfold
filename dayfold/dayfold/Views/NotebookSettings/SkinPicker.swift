// Views/NotebookSettings/SkinPicker.swift
import SwiftUI

/// SKIN 横向滚动选择器。
/// 5 个内置样式（chevronTeal / triangleRed / stripesBlack / leatherBrown / diagonalGray）。
/// 不显示 Custom Skin（按 spec）。
struct SkinPicker: View {
    @Environment(\.theme) private var theme
    @ObservedObject var notebook: Notebook

    private let styles = NotebookCoverStyle.allCases

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(styles, id: \.rawValue) { style in
                    SkinThumb(
                        style: style,
                        isSelected: notebook.coverStyle == style
                    ) {
                        // 写 Core Data，但不立即 save — 由 NotebookSettingsSheet 的 DONE 按钮统一 save
                        notebook.coverStyle = style
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

/// 单个迷你封面缩略图。复用 `CoverPatternView`(同文件 private),避免重写样式。
/// 选中态：accentPrimary 3pt 描边 + 大圆角矩形 outline。
private struct SkinThumb: View {
    @Environment(\.theme) private var theme
    let style: NotebookCoverStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                // 主封面
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.surfacePaper)
                    .overlay(
                        CoverPatternView(style: style)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    )

                // 书脊
                RoundedRectangle(cornerRadius: 8)
                    .fill(style.spineColor)
                    .frame(width: 16)
                    .clipShape(RoundedCornerShape(radius: 8, corners: [.topLeft, .bottomLeft]))
            }
            .frame(width: 60, height: 85)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? theme.accentPrimary : Color.clear,
                        lineWidth: isSelected ? 3 : 0
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// 复用 HomeView.swift 里的私有 CoverPatternView。
// 跨文件复用：把 CoverPatternView 移到独立文件最干净；这里用 fileprivate 重新声明一个
// 最小化的预览（仅颜色块），避免修改 HomeView 的私有结构。
//
// 妥协方案：本组件直接 render `RoundedRectangle + style.spineColor`，
// 不再独立渲染复杂图案 —— 缩略图 60×85 极小，图案细节不可见，
// 仅靠"主色 + 书脊色"就能区分 5 种样式。

/// 极简封面图案预览：仅展示 spine color 决定的主色块，不画复杂图案。
private struct CoverPatternView: View {
    @Environment(\.theme) private var theme
    let style: NotebookCoverStyle

    var body: some View {
        LinearGradient(
            colors: [
                style.spineColor.opacity(0.85),
                style.spineColor.opacity(0.7),
                style.spineColor.opacity(0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// 圆角辅助(拷贝自 HomeView.swift,以避免依赖私有结构)。
private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}
