// Views/SettingsView.swift
import SwiftUI
import CoreData
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var securityManager: SecurityManager

    @State private var showPasswordSetup = false
    @State private var showChangePassword = false
    @State private var showGracePicker = false
    @State private var verifyForDisable = false
    @State private var errorToken: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                passwordSection
            }
            .padding()
        }
        .background(theme.backgroundPrimary.ignoresSafeArea())
        .sheet(isPresented: $showPasswordSetup) {
            NavigationStack {
                PasswordSetupFlow()
            }
            .environment(\.theme, theme)
            .environmentObject(securityManager)
        }
        .sheet(isPresented: $showChangePassword) {
            NavigationStack {
                ChangePasswordFlow()
            }
            .environment(\.theme, theme)
            .environmentObject(securityManager)
        }
        .sheet(isPresented: $showGracePicker) {
            NavigationStack {
                LockGracePickerView()
            }
            .environment(\.theme, theme)
            .environmentObject(securityManager)
        }
        .sheet(isPresented: $verifyForDisable) {
            NavigationStack {
                disablePasswordSheet
            }
            .environment(\.theme, theme)
            .environmentObject(securityManager)
        }
    }

    // MARK: - 主卡片

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader

            VStack(spacing: 0) {
                passwordRow
                Divider().background(theme.dividerSubtle)
                changePasswordRow
                Divider().background(theme.dividerSubtle)
                graceRow
                Divider().background(theme.dividerSubtle)
                biometricRow
                if securityManager.isBiometricEnabled && securityManager.biometricsAvailable {
                    Divider().background(theme.dividerSubtle)
                    promptBiometricRow
                }
            }
            .background(theme.backgroundSecondary)
            .cornerRadius(16)
        }
    }

    // MARK: - 副标题 + 锁图标 + 了解更多

    private var sectionHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(theme.textPrimary)

            (
                Text("使用密码或生物识别技术")
                    .foregroundColor(theme.textSecondary)
                + Text("保护您的日记")
                    .foregroundColor(theme.accentPrimary)
                + Text("，防止不必要的窥探。")
                    .foregroundColor(theme.textSecondary)
                + Text(" ")
                + Text("了解更多")
                    .foregroundColor(theme.accentPrimary)
            )
            .font(.warmCaption)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    // MARK: - 行

    /// 标准行容器：左侧标题 + 中间 Spacer + 右侧控件，统一 56pt 行高，所有内容垂直居中。
    /// 标题不允许折行，避免把右侧控件挤错位。
    private func standardRow<Leading: View, Trailing: View>(
        disabled: Bool,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        action: (() -> Void)? = nil
    ) -> some View {
        let row = HStack(spacing: 12) {
            leading()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 12)
            trailing()
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .center)
        .padding(.horizontal, 16)
        .opacity(disabled ? 0.5 : 1)

        if let action {
            return AnyView(
                Button {
                    if !disabled { action() }
                } label: { row }
                    .buttonStyle(.plain)
                    .disabled(disabled)
            )
        } else {
            return AnyView(row)
        }
    }

    private var passwordRow: some View {
        standardRow(disabled: false, leading: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(theme.accentPrimary)
                Text("密码")
                    .font(.warmBody)
                    .foregroundColor(theme.textPrimary)
            }
        }, trailing: {
            Toggle(
                "",
                isOn: Binding(
                    get: { securityManager.hasPassword },
                    set: { newValue in
                        if newValue {
                            showPasswordSetup = true
                        } else {
                            verifyForDisable = true
                        }
                    }
                )
            )
            .labelsHidden()
            .tint(theme.accentPrimary)
        })
    }

    private var changePasswordRow: some View {
        standardRow(
            disabled: !securityManager.hasPassword,
            leading: {
                Text("变更密码")
                    .font(.warmBody)
                    .foregroundColor(securityManager.hasPassword ? theme.textPrimary : theme.textTertiary)
            },
            trailing: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(theme.textTertiary)
            },
            action: { showChangePassword = true }
        )
    }

    private var graceRow: some View {
        standardRow(
            disabled: !securityManager.hasPassword,
            leading: {
                Text("在…后要求")
                    .font(.warmBody)
                    .foregroundColor(securityManager.hasPassword ? theme.textPrimary : theme.textTertiary)
            },
            trailing: {
                HStack(spacing: 8) {
                    Text(securityManager.lockGrace.label)
                        .font(.warmBody)
                        .foregroundColor(securityManager.hasPassword ? theme.textSecondary : theme.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(theme.textTertiary)
                }
            },
            action: { showGracePicker = true }
        )
    }

    private var biometricRow: some View {
        let biometricLabel = biometricLabelForCurrentDevice()
        let canToggle = securityManager.biometricsAvailable
        return standardRow(
            disabled: !canToggle,
            leading: {
                HStack(spacing: 12) {
                    Image(systemName: "faceid")
                        .foregroundColor(theme.accentPrimary)
                    Text(biometricLabel)
                        .font(.warmBody)
                        .foregroundColor(canToggle ? theme.textPrimary : theme.textTertiary)
                }
            },
            trailing: {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { securityManager.isBiometricEnabled },
                        set: { securityManager.setBiometricEnabled($0) }
                    )
                )
                .labelsHidden()
                .tint(theme.accentPrimary)
                .disabled(!canToggle)
            }
        )
    }

    private var promptBiometricRow: some View {
        standardRow(
            disabled: false,
            leading: {
                Text("提示 Face ID")
                    .font(.warmBody)
                    .foregroundColor(theme.textPrimary)
            },
            trailing: {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { securityManager.promptForBiometric },
                        set: { securityManager.setPromptBiometric($0) }
                    )
                )
                .labelsHidden()
                .tint(theme.accentPrimary)
            }
        )
    }

    // MARK: - 关闭密码验证页（sheet）

    private var disablePasswordSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { verifyForDisable = false }
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("关闭密码")
                    .font(.warmHeadline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Color.clear.frame(width: 44, height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            PinKeypadView(
                title: "输入当前密码",
                subtitle: nil,
                onComplete: handleDisableComplete,
                isDisabled: false
            )
            .id(errorToken)
        }
        .background(theme.backgroundPrimary.ignoresSafeArea())
    }

    private func handleDisableComplete(_ pin: String) {
        if securityManager.verifyPassword(pin) {
            // verifyPassword 已校验过，可直接 forceClearPassword
            securityManager.forceClearPassword()
            verifyForDisable = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            errorToken += 1
        }
    }

    // MARK: - 工具

    private func biometricLabelForCurrentDevice() -> String {
        let ctx = LAContextProbe()
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Face ID"
        }
    }
}

/// 一次性 LAContext 探测，不复用 SecurityManager 内部的（它会因为 evaluatePolicy
/// 失败而被 invalidate）。
private struct LAContextProbe {
    let biometryType: LABiometryType

    init() {
        let ctx = LAContext()
        var error: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            self.biometryType = ctx.biometryType
        } else {
            self.biometryType = .none
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.theme, WarmDarkTheme())
        .environmentObject(SecurityManager())
}
