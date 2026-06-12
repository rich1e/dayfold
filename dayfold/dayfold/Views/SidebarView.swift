// Views/SidebarView.swift
import SwiftUI

enum SidebarTab: String, CaseIterable, Hashable {
    case timeline, list, tags

    var icon: String {
        switch self {
        case .timeline: return "clock"
        case .list:     return "book.closed"
        case .tags:     return "tag"
        }
    }

    var label: String {
        switch self {
        case .timeline: return "时间轴"
        case .list:     return "全部"
        case .tags:     return "标签"
        }
    }
}

struct DrawerView: View {
    @Binding var selectedTab: SidebarTab
    @Binding var isOpen: Bool

    @Namespace private var drawerNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题区
            HStack {
                Text("Dayfold")
                    .font(.warmTitle)
                    .foregroundColor(.warmBrown)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.warmBrown.opacity(0.6))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 24)

            Divider()
                .background(Color.warmCream)
                .padding(.horizontal, 20)

            // 导航项列表
            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    DrawerItem(
                        tab: tab,
                        isActive: selectedTab == tab,
                        namespace: drawerNamespace
                    ) {
                        selectedTab = tab
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isOpen = false
                        }
                    }
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.warmLight)
    }
}

private struct DrawerItem: View {
    let tab: SidebarTab
    let isActive: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                if isActive {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.warmAccent.opacity(0.12))
                        .matchedGeometryEffect(id: "activeTab", in: namespace)
                }

                HStack(spacing: 14) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .warmAccent : .warmBrown.opacity(0.55))
                        .frame(width: 24)

                    Text(tab.label)
                        .font(.system(size: 16, weight: isActive ? .semibold : .regular, design: .rounded))
                        .foregroundColor(isActive ? .warmAccent : .warmBrown)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DrawerView(selectedTab: .constant(.timeline), isOpen: .constant(true))
        .frame(width: 300)
}
