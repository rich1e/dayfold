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

private let drawerBg = Color(red: 0.18, green: 0.18, blue: 0.20)
private let drawerRowBg = Color(red: 0.22, green: 0.22, blue: 0.24)
private let drawerDivider = Color(red: 0.28, green: 0.28, blue: 0.30)
private let drawerAccent = Color(red: 0.95, green: 0.45, blue: 0.35)
private let drawerText = Color(red: 0.92, green: 0.92, blue: 0.92)

struct DrawerView: View {
    @Binding var selectedTab: SidebarTab
    @Binding var isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题
            HStack {
                Text("DAYFOLD")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundColor(drawerAccent)
                    .tracking(2)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 20)

            // 导航列表
            VStack(spacing: 0) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    DrawerRow(
                        tab: tab,
                        isActive: selectedTab == tab
                    ) {
                        selectedTab = tab
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isOpen = false
                        }
                    }

                    if tab != SidebarTab.allCases.last {
                        Divider()
                            .background(drawerDivider)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(drawerBg.ignoresSafeArea())
    }
}

private struct DrawerRow: View {
    let tab: SidebarTab
    let isActive: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(isActive ? drawerAccent : drawerText)
                    .frame(width: 22)

                Text(tab.label)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(isActive ? drawerAccent : drawerText)

                Spacer()

                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(drawerAccent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(isPressed ? drawerRowBg : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isPressed { isPressed = true } }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    DrawerView(selectedTab: .constant(.timeline), isOpen: .constant(true))
        .frame(width: 300)
}
