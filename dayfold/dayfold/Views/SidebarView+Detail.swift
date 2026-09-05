// Views/SidebarView+Detail.swift
// 抽屉内二级页面容器与路由分发。
// 取代原先"点击抽屉行 → 关闭抽屉 + selectedTab 切换 + 整页 paperDrop 转场"的旧交互，
// 改为"点击抽屉行 → 在抽屉内部从右侧滑入二级页，左侧抽屉列表保留窄条作为返回锚点"。

import SwiftUI
import CoreData

/// 抽屉内二级页通用容器。
///
/// 视觉上占据整个抽屉宽度（85% 屏宽），顶部带返回箭头 + 标题。
/// 动画：从抽屉宽度右侧外滑入；从抽屉宽度向右侧外滑出。
struct DrawerDetailContainer<Content: View>: View {
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
                        .foregroundColor(drawerGroupLabel)
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
/// 所有二级页统一传入 `viewContext`，与 `MainTabView` 内容区保持一致。
/// `MapView` 需要 `Binding<Bool>` 用于"新建条目"sheet；这里用本地 state，
/// 避免与 `MainTabView` 的 `showingNewEntry` 状态耦合。
struct DrawerDetailRouter: View {
    let tab: SidebarTab
    let context: NSManagedObjectContext

    @State private var drawerMapShowingNewEntry = false

    var body: some View {
        switch tab {
        case .list:
            EntryListView(context: context)
        case .photos:
            // 相册：当前复用 EntryListView，后续可加"仅图片"筛选
            EntryListView(context: context)
        case .tags:
            TagsView(context: context)
        case .map:
            MapView(showingNewEntry: $drawerMapShowingNewEntry)
        case .trash:
            TrashView()
        case .stats:
            StatsView(context: context)
        case .settings:
            SettingsView()
        }
    }
}
