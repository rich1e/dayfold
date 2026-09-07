// Views/Security/PasswordUnlockView.swift
import SwiftUI

/// 锁屏页输入密码解锁。
struct PasswordUnlockView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var securityManager: SecurityManager
    @State private var errorToken: Int = 0

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                PinKeypadView(
                    title: "输入密码",
                    subtitle: subtitleText,
                    onComplete: handleComplete,
                    isDisabled: securityManager.isInCooldown
                )
                .id(errorToken)
                Spacer(minLength: 0)
            }
        }
    }

    private var subtitleText: String? {
        if let c = securityManager.cooldown {
            let secs = Int(c.remaining.rounded(.up))
            return "请稍后再试 (\(secs)s)"
        }
        return nil
    }

    private func handleComplete(_ pin: String) {
        if securityManager.verifyPassword(pin) {
            // 成功：SecurityManager 内部把 isLocked = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            errorToken += 1
        }
    }
}

#Preview {
    PasswordUnlockView()
        .environment(\.theme, WarmDarkTheme())
        .environmentObject(SecurityManager())
}
