// Views/Security/PasswordSetupFlow.swift
import SwiftUI

/// 首次设置密码的两步流程：输入新密码 → 重新输入新密码。
/// 不匹配则回到第一步并抖动。
struct PasswordSetupFlow: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var securityManager: SecurityManager
    @Environment(\.dismiss) private var dismiss

    enum Step { case createNew, confirmNew }

    @State private var step: Step = .createNew
    @State private var firstPin: String = ""
    @State private var errorToken: Int = 0

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                keypad
                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack {
            Button {
                goBackOrDismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text("密码")
                .font(.warmHeadline)
                .foregroundColor(theme.textPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
    }

    // MARK: - 键盘

    private var keypad: some View {
        PinKeypadView(
            title: step == .createNew ? "输入新密码" : "重新输入新密码",
            subtitle: nil,
            onComplete: handleComplete,
            isDisabled: false
        )
        .id(errorToken)
    }

    // MARK: - 流程

    private func handleComplete(_ pin: String) {
        switch step {
        case .createNew:
            firstPin = pin
            step = .confirmNew
            // 步骤切换时重建 PinKeypadView 清空内部 pin
            errorToken += 1
        case .confirmNew:
            if pin == firstPin {
                securityManager.setPassword(pin)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } else {
                // 不匹配 → 抖动 + 回到第一步
                firstPin = ""
                step = .createNew
                errorToken += 1
            }
        }
    }

    private func goBackOrDismiss() {
        switch step {
        case .createNew:
            dismiss()
        case .confirmNew:
            firstPin = ""
            step = .createNew
        }
    }
}

extension Notification.Name {
    /// PinKeypadView 监听此通知以触发错误抖动 / 清空。
    /// 由父流程页在子组件不可直接持有的场景下发出。
    static let pinKeypadError = Notification.Name("pinKeypadError")
}

// 注：错误传递改用 `errorToken` 重建 PinKeypadView，无需 NotificationCenter。
// 保留该扩展占位，避免未来扩展时再去查找。

#Preview {
    PasswordSetupFlow()
        .environment(\.theme, WarmDarkTheme())
        .environmentObject(SecurityManager())
}
