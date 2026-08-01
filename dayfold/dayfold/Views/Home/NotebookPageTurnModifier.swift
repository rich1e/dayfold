// Views/Home/NotebookPageTurnModifier.swift
import SwiftUI
import CoreGraphics

/// 笔记本封面 3D 翻页 modifier。
///
/// 给定当前页 idx 与 currentIndex binding,渲染时:
/// - 当前页(idx == currentIndex):沿左侧书脊向左翻,progress 从 0 → -1,rotation Y 从 0° → -90°,阴影 X 偏移从 0 → -24
/// - 下一页(idx == currentIndex + 1):从右侧翻入,progress 从 1 → 0,rotation Y 从 90° → 0°,阴影 X 偏移从 +24 → 0
/// - 其他页:opacity 0 + rotation 固定(不可见)
struct NotebookPageTurnModifier: ViewModifier {
    let idx: Int
    @Binding var currentIndex: Int

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .rotation3DEffect(
                rotationAngle,
                axis: (x: 0, y: 1, z: 0),
                anchor: UnitPoint(x: 0.13, y: 0.5),  // 左侧书脊位置(240 宽中 0.26/2 ≈ 0.13)
                perspective: 0.5                       // iOS 18 rotation3DEffect 用 perspective,等价 m34 = -1/perspective
            )
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: 24,
                x: shadowX,
                y: 16
            )
            .transition(.identity)  // 禁用 TabView 自带 transition,避免与 3D 冲突
            .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.78), value: currentIndex)
    }

    // MARK: - 计算属性

    /// 该页相对 currentIndex 的位置差
    private var diff: Int { idx - currentIndex }

    /// 旋转角度(.degrees)
    private var rotationAngle: Angle {
        switch diff {
        case 0:    return .degrees(0)        // 当前页(初始 / 翻完归位)
        case 1:    return .degrees(90)       // 下一页(从右待翻入)
        case -1:   return .degrees(-90)      // 上一页(已翻出)
        default:   return diff > 0 ? .degrees(90) : .degrees(-90)
        }
    }

    private var opacity: Double {
        switch diff {
        case 0:                  return 1.0   // 当前页实色
        case 1, -1:              return 0.3   // 相邻页半透明(待翻入 / 已翻出)
        default:                 return 0.0
        }
    }

    private var shadowOpacity: Double {
        diff == 0 ? 0.55 : 0.0
    }

    private var shadowX: CGFloat {
        diff == 0 ? 0 : (diff == 1 ? 24 : -24)
    }
}

extension View {
    /// 快捷应用翻页 modifier(单本时 diff 永远 = 0,等价无操作)
    func notebookPageTurn(idx: Int, currentIndex: Binding<Int>) -> some View {
        self.modifier(NotebookPageTurnModifier(idx: idx, currentIndex: currentIndex))
    }
}
