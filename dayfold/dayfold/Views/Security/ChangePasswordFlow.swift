// Views/Security/ChangePasswordFlow.swift
import SwiftUI

/// 更改密码的三步流程：验证旧密码 → 输入新密码 → 重新输入新密码。
struct ChangePasswordFlow: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var securityManager: SecurityManager
    @Environment(\.dismiss) private var dismiss

    enum Step { case verifyOld, createNew, confirmNew }

    @State private var step: Step = .verifyOld
    @State private var oldPin: String = ""
    @State private var newPin: String = ""
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
        // 用 errorToken 作为 id 让 PinKeypadView 在错误时重建，从而触发错误反馈
        PinKeypadView(
            title: titleForStep,
            subtitle: nil,
            onComplete: handleComplete,
            isDisabled: false
        )
        .id(errorToken)
    }

    private var titleForStep: String {
        switch step {
        case .verifyOld:  return "输入当前密码"
        case .createNew:  return "输入新密码"
        case .confirmNew: return "重新输入新密码"
        }
    }

    // MARK: - 流程

    private func handleComplete(_ pin: String) {
        switch step {
        case .verifyOld:
            if securityManager.verifyPassword(pin) {
                step = .createNew
                errorToken += 1
            } else {
                oldPin = ""
                errorToken += 1
            }
        case .createNew:
            newPin = pin
            step = .confirmNew
            errorToken += 1
        case .confirmNew:
            if pin == newPin {
                securityManager.setPassword(pin)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } else {
                newPin = ""
                step = .createNew
                errorToken += 1
            }
        }
    }

    private func goBackOrDismiss() {
        switch step {
        case .verifyOld:
            dismiss()
        case .createNew:
            newPin = ""
            step = .verifyOld
        case .confirmNew:
            newPin = ""
            step = .createNew
        }
    }
}

#Preview {
    ChangePasswordFlow()
        .environment(\.theme, WarmDarkTheme())
        .environmentObject(SecurityManager())
}
