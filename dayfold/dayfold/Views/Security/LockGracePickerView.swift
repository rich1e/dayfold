// Views/Security/LockGracePickerView.swift
import SwiftUI

/// 设置页「在…后要求」子菜单：单选延时。
struct LockGracePickerView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var securityManager: SecurityManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                list
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text("在…后要求")
                .font(.warmHeadline)
                .foregroundColor(theme.textPrimary)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(SecurityManager.LockMode.allCases) { mode in
                Button {
                    securityManager.setLockGrace(mode)
                    dismiss()
                } label: {
                    HStack {
                        Text(mode.label)
                            .font(.warmBody)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        if securityManager.lockGrace == mode {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.accentPrimary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(theme.backgroundSecondary)
                }
                .buttonStyle(.plain)

                if mode != SecurityManager.LockMode.allCases.last {
                    Divider()
                        .background(theme.dividerSubtle)
                        .padding(.horizontal, 20)
                }
            }
        }
        .background(theme.backgroundSecondary)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    LockGracePickerView()
        .environment(\.theme, WarmDarkTheme())
        .environmentObject(SecurityManager())
}
