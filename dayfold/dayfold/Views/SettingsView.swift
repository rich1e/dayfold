// Views/SettingsView.swift
import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var securityManager: SecurityManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                securityCard
            }
            .padding()
        }
        .background(theme.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: - Face ID 锁定

    private var securityCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "faceid")
                .foregroundColor(theme.accentPrimary)
            Text("Face ID 锁定")
                .font(.warmBody)
                .foregroundColor(theme.textPrimary)
            Spacer()
            Toggle(
                "",
                isOn: Binding(
                    get: { securityManager.isEnabled },
                    set: { securityManager.setEnabled($0) }
                )
            )
            .labelsHidden()
            .tint(theme.accentPrimary)
        }
        .padding()
        .warmCard()
    }
}
