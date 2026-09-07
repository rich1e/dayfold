// Views/LockScreenView.swift
import SwiftUI

/// 锁屏页：固定展示密码输入页。
/// 密码页左下角自带 Face ID 图标按钮（点击触发生物识别），
/// 顶部不再放 Segmented 切换条，避免与键盘内 Face ID 图标语义重复。
struct LockScreenView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var securityManager: SecurityManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.dividerPrimary, theme.backgroundPrimary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                brandHeader
                    .padding(.top, 48)

                Spacer(minLength: 0)

                PasswordUnlockView()

                Spacer(minLength: 0)

                Text("忘记密码？")
                    .font(.warmCaption)
                    .foregroundColor(theme.textSecondary)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            // 锁屏出现时如果用户开启了「提示 Face ID」且设备有生物识别硬件，
            // 自动尝试一次 Face ID；失败用户可继续输入密码或点键盘左下角图标重试。
            tryAutoBiometricIfNeeded()
        }
    }

    private func tryAutoBiometricIfNeeded() {
        guard securityManager.isBiometricEnabled,
              securityManager.promptForBiometric,
              securityManager.biometricsAvailable else { return }
        Task { _ = await securityManager.attemptBiometricUnlock() }
    }

    // MARK: - 顶部品牌区

    private var brandHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 32))
                .foregroundColor(theme.accentPrimary)
                .opacity(0.4)
            Text("Dayfold")
                .font(.warmCaption)
                .foregroundColor(theme.textSecondary)
                .opacity(0.6)
        }
    }
}

#Preview {
    LockScreenView()
        .environment(\.theme, WarmDarkTheme())
        .environmentObject(SecurityManager())
}
