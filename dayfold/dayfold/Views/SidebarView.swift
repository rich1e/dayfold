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

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    var onNewEntry: () -> Void

    @Namespace private var sidebarNamespace
    @State private var fabPressed = false

    var body: some View {
        VStack(spacing: 0) {
            // 导航项
            VStack(spacing: 4) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    SidebarItem(
                        tab: tab,
                        isActive: selectedTab == tab,
                        namespace: sidebarNamespace
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.top, 16)

            Spacer()

            // FAB 新建按钮
            Button {
                onNewEntry()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.warmAccent)
                    .clipShape(Circle())
                    .shadow(
                        color: Color.warmAccent.opacity(0.35),
                        radius: 8, x: 0, y: 3
                    )
                    .scaleEffect(fabPressed ? 0.9 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !fabPressed {
                            withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                                fabPressed = true
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            fabPressed = false
                        }
                    }
            )
            .padding(.bottom, 24)
        }
        .frame(width: 48)
        .background(Color.warmLight)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.warmCream)
                .frame(width: 1)
        }
    }
}

private struct SidebarItem: View {
    let tab: SidebarTab
    let isActive: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.warmAccent.opacity(0.13))
                        .frame(width: 36, height: 36)
                        .matchedGeometryEffect(id: "activeTab", in: namespace)
                }

                VStack(spacing: 3) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .warmAccent : .warmBrown.opacity(0.6))

                    Text(tab.label)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(isActive ? .warmAccent : .warmBrown.opacity(0.6))
                }
                .frame(width: 36, height: 36)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HStack {
        SidebarView(selectedTab: .constant(.timeline), onNewEntry: {})
        Spacer()
    }
    .background(Color.warmPaper)
}
