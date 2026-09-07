// Views/Security/PinKeypadView.swift
import SwiftUI
import UIKit

/// 复用的 4 位 PIN 输入组件。父视图通过 `onComplete(pin)` 接管 4 位输完后的逻辑。
struct PinKeypadView: View {
    enum Mode { case create, verify, change }

    @Environment(\.theme) private var theme

    /// 输入框顶部主标题。
    let title: String
    /// 副标题（用于错误反馈文案，nil 则不显示）。
    let subtitle: String?
    /// 4 位输完回调。
    var onComplete: (String) -> Void
    /// 是否禁用整个键盘（冷却期 / 流程结束）。
    var isDisabled: Bool = false

    @State private var pin: String = ""
    @State private var dotsShakeTrigger: Int = 0
    @State private var isError: Bool = false
    @State private var lastFlashedErrorAt: Date?

    /// 上次报错时间（毫秒），用于防止重入。
    private let errorFlashCooldown: TimeInterval = 0.45

    var body: some View {
        VStack(spacing: 32) {
            dotsIndicator
                .modifier(ShakeEffect(animatableData: CGFloat(dotsShakeTrigger)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .safeAreaInset(edge: .bottom) { keypad }
    }

    // MARK: - 圆点

    private var dotsIndicator: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.warmBody)
                .foregroundColor(isError ? theme.accentDestructive : theme.textPrimary)
                .animation(.easeInOut(duration: 0.15), value: isError)

            if let subtitle {
                Text(subtitle)
                    .font(.warmCaption)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 24) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .stroke(theme.dividerPrimary, lineWidth: 1.5)
                        .background(
                            Circle().fill(fillColor(at: i))
                        )
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.top, 8)
        }
    }

    private func fillColor(at index: Int) -> Color {
        if index < pin.count {
            return isError ? theme.accentDestructive : theme.textPrimary
        }
        return Color.clear
    }

    // MARK: - 键盘

    private var keypad: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { col in
                        let digit = row * 3 + col
                        keyButton(digit: String(digit), subtitle: nil)
                    }
                }
            }
            HStack(spacing: 0) {
                keyPlaceholder()
                keyButton(digit: "0", subtitle: nil)
                keyButton(action: backspace, systemImage: "delete.left", subtitle: nil)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    /// 左下角空位（与右下角 `←` 对称占位）。透明 + 不可点。
    private func keyPlaceholder() -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func keyButton(digit: String, subtitle: String?) -> some View {
        Button {
            handleDigit(digit)
        } label: {
            VStack(spacing: 2) {
                Text(digit)
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .foregroundColor(theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.warmFootnote)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(KeypadButtonStyle(theme: theme))
    }

    @ViewBuilder
    private func keyButton(action: @escaping () -> Void, systemImage: String, subtitle: String?) -> some View {
        Button(action: action) {
            // 与数字键视觉对齐：用与数字等大的"假字符"占位，让 `←` 图标垂直居中到与数字键基线一致。
            ZStack {
                Text("0")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .foregroundColor(.clear)
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(KeypadButtonStyle(theme: theme))
    }

    // MARK: - 交互

    private func handleDigit(_ d: String) {
        guard !isDisabled, pin.count < 4 else { return }
        pin.append(d)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if pin.count == 4 {
            let snapshot = pin
            // 通知父级后延迟清空，让圆点保持显示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                onComplete(snapshot)
            }
        }
    }

    private func backspace() {
        guard !isDisabled, !pin.isEmpty else { return }
        pin.removeLast()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 由父视图在验证失败后调用：触发抖动 + 错误色 + 触觉反馈。
    func triggerError() {
        let now = Date()
        if let last = lastFlashedErrorAt, now.timeIntervalSince(last) < errorFlashCooldown {
            return
        }
        lastFlashedErrorAt = now
        isError = true
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        withAnimation(.easeInOut(duration: 0.08)) {
            dotsShakeTrigger += 1
        }
        // 清空 PIN 让用户重新输入
        pin = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isError = false
        }
    }

    /// 由父视图在流程切换步骤时调用，重置 PIN。
    func resetPin() {
        pin = ""
        isError = false
    }
}

// MARK: - 抖动效果

private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let amount: CGFloat = 6
        let shakesPerUnit: CGFloat = 3
        let x = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

// MARK: - 按钮按下态

private struct KeypadButtonStyle: ButtonStyle {
    let theme: DayfoldTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(theme.backgroundPressed.opacity(configuration.isPressed ? 0.6 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    PinKeypadView(title: "输入新密码", subtitle: nil, onComplete: { _ in })
        .environment(\.theme, WarmDarkTheme())
}
