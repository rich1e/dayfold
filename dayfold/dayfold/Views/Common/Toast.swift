// Views/Common/Toast.swift
import SwiftUI

/// 轻量 Toast 消息。识别通过 `id`,相同 id 不会重新触发动画。
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var duration: TimeInterval = 2.0
}

/// Toast UI:深灰胶囊背景 + 白字,居中底部,自动 2s 消失。
struct ToastView: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(theme.backgroundElevated.opacity(0.95))
            )
            .shadow(color: theme.shadowOverlay, radius: 8, x: 0, y: 4)
    }
}

/// 把 Toast 挂到任意 View 上:用 `.toast($toast)` 即可。
/// 通过 `message` 的 id 变化驱动 .task,自动 dismiss。
struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let msg = message {
                    ToastView(text: msg.text)
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: msg.id) {
                            try? await Task.sleep(nanoseconds: UInt64(msg.duration * 1_000_000_000))
                            withAnimation(.easeOut(duration: 0.2)) {
                                if message?.id == msg.id {
                                    message = nil
                                }
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: message?.id)
    }
}

extension View {
    /// 在底部叠加一个 Toast。绑定置 nil 时立刻消失。
    /// - Parameter bottomInset: 距底部的额外偏移(默认 80,避开 safeAreaInset 的 bottom toolbar)。
    func toast(_ message: Binding<ToastMessage?>, bottomInset: CGFloat = 80) -> some View {
        modifier(ToastModifier(message: message))
    }
}

#Preview {
    Demo()
        .environment(\.theme, WarmDarkTheme())
}

private struct Demo: View {
    @Environment(\.theme) private var theme
    @State var toast: ToastMessage?
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Button("显示 Toast") {
                toast = ToastMessage(text: "1 个条目已恢复为日记")
            }
            .foregroundColor(.white)
        }
        .toast($toast)
    }
}
