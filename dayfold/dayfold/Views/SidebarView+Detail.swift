// Views/SidebarView+Detail.swift
// 抽屉内二级页面容器与路由分发。
// 点击抽屉行 → 在抽屉内部从右侧滑入二级页，左侧抽屉列表保留窄条作为返回锚点。

import SwiftUI
import CoreData

/// 抽屉内二级页通用容器。
///
/// 视觉上占据整个抽屉宽度（85% 屏宽），顶部带返回箭头 + 标题。
/// 动画：从抽屉宽度右侧外滑入；从抽屉宽度向右侧外滑出。
struct DrawerDetailContainer<Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    let drawerWidth: CGFloat
    let onBack: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏：返回箭头 + 标题
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(drawerGroupLabelColor)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(drawerText)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 16)
            .background(drawerBg)

            // 二级页正文
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(drawerBg)
        }
        .frame(width: drawerWidth)
        .frame(maxHeight: .infinity)
        .background(drawerBg.ignoresSafeArea())
        .offset(x: appear ? 0 : drawerWidth)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                appear = true
            }
        }
    }
}

/// 抽屉二级页路由分发：根据 `SidebarTab` 返回对应 View。
///
/// - `list/trash/stats` 路由到真实页面
/// - 其他装饰类入口（icloud/memories/notifications/hiddenAlbum/about）渲染占位详情
/// - `privacy` 复用现有 `SettingsView`（包含 Face ID 开关）
struct DrawerDetailRouter: View {
    @Environment(\.theme) private var theme
    let tab: SidebarTab
    let context: NSManagedObjectContext
    let securityManager: SecurityManager

    var body: some View {
        switch tab {
        case .list:
            EntryListView(context: context)

        case .icloud:
            DrawerPlaceholderDetail(
                icon: "icloud",
                title: "iCloud Sync",
                subtitle: "On · 12.4 GB of 50 GB"
            )
        case .memories:
            DrawerPlaceholderDetail(
                icon: "sparkles",
                title: "Memories",
                subtitle: "Curated weekly"
            )
        case .notifications:
            DrawerPlaceholderDetail(
                icon: "bell",
                title: "Notifications",
                subtitle: "Memories · Shared albums"
            )
        case .privacy:
            SettingsView()
        case .hiddenAlbum:
            DrawerPlaceholderDetail(
                icon: "eye.slash",
                title: "Hidden Album",
                subtitle: "Off"
            )

        case .stats:
            StatsView(context: context)
        case .trash:
            TrashView()
        case .about:
            DrawerPlaceholderDetail(
                icon: "info.circle",
                title: "About Photos",
                subtitle: aboutSubtitle
            )
        }
    }

    private var aboutSubtitle: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(v) · Build \(b)"
    }
}

/// 装饰类入口的占位详情页（与抽屉配色对齐）
private struct DrawerPlaceholderDetail: View {
    @Environment(\.theme) private var theme
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(drawerGroupLabelColor.opacity(0.7))
            Text(title)
                .font(.warmHeadline)
                .foregroundColor(drawerText)
            Text(subtitle)
                .font(.warmCaption)
                .foregroundColor(drawerBrown)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(drawerBg.ignoresSafeArea())
    }
}
