// Views/Home/NotebookCarousel.swift
import SwiftUI

/// 3D Cover Flow 风格的笔记本翻页容器。
///
/// 用 `ZStack` + `DragGesture` 自管手势，实现：
/// - 拖拽时所有卡片实时跟随手指旋转（continuous, 非离散跳变）
/// - 松手根据阈值决定回弹或换页（spring 动画）
/// - 中心卡片 0°/满不透明/满尺寸;相邻卡片 18° Y 轴扇形 + 0.88 缩放 + 整张卡片水平滑出
///   (peekOffset = cardWidth × 0.55),永远有清晰背景间隙,绝不重叠
/// - peek 卡片同样不透明 + 加独立阴影,保持视觉层次
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

private let cardWidth: CGFloat = 204
    private let cardHeight: CGFloat = 289
    /// 相邻卡片水平滑出量 — 用卡片宽度的 55% 拉开距离,确保中心卡片与 peek 卡片之间留出明显间隙
    private let peekOffsetRatio: CGFloat = 0.55
    /// 最大 Y 轴旋转角（参考视频实测 15-20°）
    private let maxRotation: Double = 18
    /// 翻页阈值（pt）
    private let swipeThreshold: CGFloat = 80
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
        // 仅缩小 peek 卡片,中心卡片保持 1.0;distance > 1 的更远卡片继续缩小
        let scale = 1.0 - min(abs(normalized) * 0.12, 0.18)
        // 整张卡片水平滑出(基于卡片宽度),确保中心与 peek 之间永远留有间隙
        let offsetX = CGFloat(normalized) * cardWidth * peekOffsetRatio
        // z-index: 离中心越近越大 → 中心卡片最后绘制,自然覆盖 peek
        let zIndex = -abs(Double(idx - currentIndex))
        // 仅中心卡片可点击
        let isCenter = abs(normalized) < 0.5

        NotebookCoverView(
            notebook: notebook,
            editingNotebook: .constant(nil)   // 设置面板由 i 徽章触发，carousel 不直接管
        ) {
            onTap(idx)
        }
        .frame(width: cardWidth, height: cardHeight)
        .scaleEffect(scale)
        // 阴影放在 offset/rotation 之前,保证 peek 卡片有独立阴影与中心卡片分离
        .shadow(
            color: .black.opacity(isCenter ? 0.45 : 0.3),
            radius: isCenter ? 24 : 14,
            x: isCenter ? 0 : (normalized < 0 ? 8 : -8),
            y: 12
        )
        .offset(x: offsetX)
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0, y: 1, z: 0),
            anchor: .center,
            perspective: 0.4
        )
        .zIndex(zIndex)
        .allowsHitTesting(isCenter)
    }
}