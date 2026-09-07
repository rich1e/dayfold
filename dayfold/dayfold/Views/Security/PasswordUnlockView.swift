// Views/Security/PasswordUnlockView.swift
import SwiftUI
import LocalAuthentication

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
                    isDisabled: securityManager.isInCooldown,
                    biometricAction: shouldShowBiometricButton ? triggerBiometric : nil,
                    biometricIconName: biometricIconName
                )
                .id(errorToken)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 生物识别

    /// 是否显示左下角生物识别按钮。
    /// 显示条件只看用户在 Settings 中是否开启了 Face ID 主开关。
    /// **不**要求「提示 Face ID」开关打开、**不**要求当前设备真的有生物识别硬件。
    private var shouldShowBiometricButton: Bool {
        securityManager.isBiometricEnabled
    }

    /// 当前设备是否真的有可用的生物识别硬件。用于点击时决定是否真触发 LAContext。
    private var biometricsAvailable: Bool {
        securityManager.biometricsAvailable
    }

    private var biometricIconName: String {
        // 使用 SF Symbol `faceid`（系统提供，可靠加载）。
        // 真实接入用户提供的 FaceIDIcon.png 时，改为 "FaceIDIcon" 即可。
        "faceid"
    }

    private func triggerBiometric() {
        guard biometricsAvailable else {
            // 设备无生物识别硬件：模拟器或未设置时，不调 LAContext 避免弹错。
            // 按钮仍然可点，但仅做触觉反馈，不弹任何系统对话框。
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return
        }
        Task { _ = await securityManager.attemptBiometricUnlock() }
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
