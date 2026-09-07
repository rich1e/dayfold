// Views/LockScreenView.swift
import SwiftUI

/// 复合解锁页：根据 SecurityManager 配置在 Face ID / 密码 间切换。
struct LockScreenView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var securityManager: SecurityManager

    enum UnlockMode: String, CaseIterable, Identifiable {
        case password, biometric
        var id: String { rawValue }

        var label: String {
            switch self {
            case .password:  return "密码"
            case .biometric: return "Face ID"
            }
        }
    }

    @State private var mode: UnlockMode = .password
    @State private var didTryAutoBiometric = false

    private var showsSegmented: Bool {
        securityManager.hasPassword && securityManager.isBiometricEnabled
            && securityManager.biometricsAvailable
    }

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

                if showsSegmented {
                    Picker("", selection: $mode) {
                        ForEach(UnlockMode.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .tint(theme.accentPrimary)
                }

                Spacer(minLength: 0)

                Group {
                    if shouldShowBiometric {
                        biometricEntry
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else {
                        PasswordUnlockView()
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }

                Spacer(minLength: 0)

                Text("忘记密码？")
                    .font(.warmCaption)
                    .foregroundColor(theme.textSecondary)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            // 决定初始模式
            if showsSegmented {
                mode = securityManager.promptForBiometric ? .biometric : .password
            } else if securityManager.isBiometricEnabled
                        && securityManager.promptForBiometric
                        && securityManager.biometricsAvailable
                        && !securityManager.hasPassword {
                // 仅生物识别模式
                mode = .biometric
            } else {
                mode = .password
            }
            tryAutoBiometricIfNeeded()
        }
        .onChange(of: mode) { _, _ in
            didTryAutoBiometric = false
            tryAutoBiometricIfNeeded()
        }
    }

    /// 是否应该显示 Face ID 入口。
    /// - 仅当生物识别可用 + 已开启 + 当前 mode == biometric
    /// - 或仅生物识别模式（无密码）
    private var shouldShowBiometric: Bool {
        guard securityManager.biometricsAvailable,
              securityManager.isBiometricEnabled,
              securityManager.promptForBiometric else { return false }
        if showsSegmented { return mode == .biometric }
        // 非 segmented 场景：仅当无密码时走生物识别
        return !securityManager.hasPassword
    }

    private func tryAutoBiometricIfNeeded() {
        guard shouldShowBiometric, !didTryAutoBiometric else { return }
        didTryAutoBiometric = true
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

    // MARK: - Face ID 入口

    private var biometricEntry: some View {
        VStack(spacing: 24) {
            Image(systemName: "faceid")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(theme.accentPrimary)

            Text("使用面容 ID 解锁")
                .font(.warmBody)
                .foregroundColor(theme.textSecondary)

            Button {
                Task { _ = await securityManager.attemptBiometricUnlock() }
            } label: {
                Text("重新尝试")
                    .font(.warmBody)
                    .foregroundColor(theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.backgroundSecondary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 48)
        }
    }
}

#Preview {
    LockScreenView()
        .environment(\.theme, WarmDarkTheme())
        .environmentObject(SecurityManager())
}
