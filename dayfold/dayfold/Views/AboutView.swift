// Views/AboutView.swift
import SwiftUI
import StoreKit
import UIKit

/// About 页 — 应用图标、版本信息、评分与分享入口。
/// 抽屉内二级页（DrawerDetailContainer），配色走 ThemeManager，无外部状态依赖。
struct AboutView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                appHeader

                actionCard

                infoCard

                Text("© 2026 Dayfold")
                    .font(.warmFootnote)
                    .foregroundColor(theme.textTertiary)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(DrawerPalette.bg.ignoresSafeArea())
    }

    // MARK: - 头部：App Icon + 品牌

    private var appHeader: some View {
        VStack(spacing: 12) {
            appIcon
            Text("DAYFOLD")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(theme.accentPrimary)
                .tracking(3)
            Text("Capture every fold")
                .font(.warmCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var appIcon: some View {
        Group {
            if let img = UIImage(named: "AppIcon") {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // fallback：找不到资源时显示占位 icon，避免空白
                Image(systemName: "book.closed.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(theme.accentPrimary)
                    .padding(20)
                    .background(theme.backgroundSecondary)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: theme.shadowOverlay.opacity(0.4), radius: 12, x: 0, y: 6)
    }

    // MARK: - 动作卡：评分 / 分享

    private var actionCard: some View {
        VStack(spacing: 0) {
            ActionRow(
                icon: "star.fill",
                title: "给我们评分",
                action: requestReview
            )
            Divider().background(theme.dividerSubtle).padding(.leading, 52)
            ActionRow(
                icon: "square.and.arrow.up",
                title: "与朋友分享",
                action: shareApp
            )
        }
        .background(theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 信息卡：版本 / Bundle / iOS / Engine

    private var infoCard: some View {
        VStack(spacing: 0) {
            InfoRow(label: "Version", value: versionString)
            Divider().background(theme.dividerSubtle).padding(.leading, 16)
            InfoRow(label: "Bundle", value: AboutMeta.bundleIdentifier)
            Divider().background(theme.dividerSubtle).padding(.leading, 16)
            InfoRow(label: "iOS", value: AboutMeta.minimumOSVersion)
            Divider().background(theme.dividerSubtle).padding(.leading, 16)
            InfoRow(label: "Engine", value: "SwiftUI · Core Data")
        }
        .background(theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    // MARK: - 动作

    private func requestReview() {
        // SKStoreReviewController 一次会话最多弹 3 次，OS 自动节流，
        // 用户在系统弹层里完成或跳过即可，无需再 present 控制器。
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private func shareApp() {
        let text = "Dayfold — Capture every fold\n\(AboutMeta.appStoreURL)"
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        // iPad：必须设 sourceView，否则会 crash。popover 默认锚到屏幕中心。
        if let pop = vc.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(
                x: root.view.bounds.midX,
                y: root.view.bounds.midY,
                width: 0, height: 0
            )
            pop.permittedArrowDirections = []
        }
        root.present(vc, animated: true)
    }
}

// MARK: - 行组件

/// 信息卡内的只读行：左标签 + 右值。
private struct InfoRow: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.warmBody)
                .foregroundColor(theme.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.warmBody)
                .foregroundColor(theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(minHeight: 48)
        .padding(.horizontal, 16)
    }
}

/// 动作卡内的可点击行：左侧 SF Symbol + 标题，右侧 chevron；按下高亮。
private struct ActionRow: View {
    @Environment(\.theme) private var theme
    let icon: String
    let title: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(theme.accentPrimary)
                    .frame(width: 22)

                Text(title)
                    .font(.warmBody)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(theme.dividerPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isPressed ? theme.backgroundPressed : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isPressed { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - 元数据

/// 关于页的静态元数据集中处。
/// - TODO: 上架后把 `appStoreID` 替换为 App Store Connect 的真实 app id，
///         URL 即会自动指向正确的商店页。
private enum AboutMeta {
    static let bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "—"

    /// Info.plist 的 MinimumOSVersion；缺省显示 "—"
    static let minimumOSVersion: String = {
        if let v = Bundle.main.infoDictionary?["MinimumOSVersion"] as? String, !v.isEmpty {
            return "\(v)+"
        }
        return "—"
    }()

    static let appStoreID = "PLACEHOLDER_APP_ID"
    static var appStoreURL: String {
        "https://apps.apple.com/app/id\(appStoreID)"
    }
}

#Preview {
    AboutView()
        .environment(\.theme, WarmDarkTheme())
        .frame(width: 320, height: 600)
}
