// Views/Home/NotebookCarousel.swift
import SwiftUI

/// 3D Cover Flow 风格的笔记本翻页容器。
///
/// 用 `ZStack` + `DragGesture` 自管手势，实现：
/// - 拖拽时所有卡片实时跟随手指旋转（continuous, 非离散跳变）
/// - 松手根据阈值决定回弹或换页（spring 动画）
/// - 中心卡片缩放 + 旋转 0°；相邻卡片 35° 扇形 fan + 0.85 缩放 + 0.4 不透明度
/// - 单一笔记本时 position 永远 = 0，等价无效果
///
/// 替换原 `TabView(.page)` + `NotebookPageTurnModifier`（离散跳变）。
struct NotebookCarousel: View {
    @Binding var currentIndex: Int
    let notebooks: [Notebook]
    var onTap: (Int) -> Void   // 打开 NotebookDetailView

    // MARK: 实时手势状态

    /// 当前拖拽位移（左负右正，松手时归零）
    @State private var dragX: CGFloat = 0

    // MARK: 视觉常量

    private let cardWidth: CGFloat = 240
    private let cardHeight: CGFloat = 340
    private let peekOffset: CGFloat = 36      // 相邻卡片水平露出量
    private let maxRotation: Double = 35      // 最大 Y 轴旋转角
    private let swipeThreshold: CGFloat = 80  // 翻页阈值（pt）
    private let springResponse: Double = 0.7
    private let springDamping: Double = 0.85  // 无 overshoot

    var body: some View {
        ZStack {
            ForEach(Array(notebooks.enumerated()), id: \.element.objectID) { idx, nb in
                carouselCard(idx: idx, notebook: nb)
            }
        }
        .frame(height: cardHeight)
        .contentShape(Rectangle())
        .gesture(swipeGesture)
    }

    /// 手势识别器：拖拽时实时更新 dragX；松手判定阈值。
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                dragX = value.translation.width
            }
            .onEnded { value in
                let crossed = abs(value.predictedEndTranslation.width) > swipeThreshold ||
                              abs(value.translation.width) > swipeThreshold
                withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                    dragX = 0
                    if crossed {
                        if value.translation.width < 0 {
                            currentIndex = min(currentIndex + 1, notebooks.count - 1)
                        } else {
                            currentIndex = max(currentIndex - 1, 0)
                        }
                    }
                }
            }
    }

    // MARK: - 单卡渲染

    @ViewBuilder
    private func carouselCard(idx: Int, notebook: Notebook) -> some View {
        // position 是连续值：整数索引差 + 拖拽归一化
        let position = Double(idx - currentIndex) + Double(dragX / cardWidth)
        let normalized = max(-1.5, min(1.5, position))
        let rotation = normalized * maxRotation
        let scale = 1.0 - min(abs(normalized) * 0.15, 0.2)
        let opacity = 1.0 - min(abs(normalized) * 0.6, 0.7)
        let offsetX = CGFloat(normalized) * peekOffset
        let zIndex = -abs(Double(idx - currentIndex))  // 中心卡片绘制最上

        NotebookCoverView(
            notebook: notebook,
            editingNotebook: .constant(nil)   // 设置面板由 i 徽章触发，carousel 不直接管
        ) {
            onTap(idx)
        }
        .frame(width: cardWidth, height: cardHeight)
        .offset(x: offsetX)
        .scaleEffect(scale)
        .opacity(opacity)
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0, y: 1, z: 0),
            anchor: .center,
            perspective: 0.4
        )
        .zIndex(zIndex)
        .allowsHitTesting(abs(normalized) < 0.5)   // 仅中心卡片可点
    }
}