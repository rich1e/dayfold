// Views/SidebarView.swift
import SwiftUI
import CoreData

enum SidebarTab: String, CaseIterable, Hashable {
    case list, photos, tags, map
    case trash, stats, settings

    var icon: String {
        switch self {
        case .list:     return "book.closed"
        case .photos:   return "photo.on.rectangle"
        case .tags:     return "tag.fill"
        case .map:      return "map"
        case .trash:    return "trash"
        case .stats:    return "chart.bar"
        case .settings: return "gearshape"
        }
    }

    var label: String {
        switch self {
        case .list:     return "全部日记"
        case .photos:   return "相册"
        case .tags:     return "标签"
        case .map:      return "地图"
        case .trash:    return "回收箱"
        case .stats:    return "数据统计"
        case .settings: return "设置"
        }
    }
}

// 文件内跨文件共享（SidebarView+Detail.swift 引用）
let drawerBg      = Color(red: 0.18, green: 0.18, blue: 0.20)
let drawerRowBg   = Color(red: 0.22, green: 0.22, blue: 0.24)
let drawerDivider = Color(red: 0.28, green: 0.28, blue: 0.30)
let drawerAccent  = Color(red: 0.95, green: 0.45, blue: 0.35)
let drawerText    = Color(red: 0.92, green: 0.92, blue: 0.92)
let drawerGroupLabel = Color(hex: "5BC8D8")

private let group1: [SidebarTab] = [.list, .photos, .tags, .map]
private let group2: [SidebarTab] = [.trash, .stats, .settings]

struct DrawerView: View {
    @Binding var selectedTab: SidebarTab
    @Binding var isOpen: Bool
    let context: NSManagedObjectContext

    @State private var presentedTab: SidebarTab?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack(alignment: .leading) {
                drawerList(width: width)

                if let tab = presentedTab {
                    DrawerDetailContainer(
                        title: tab.label,
                        drawerWidth: width,
                        onBack: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                presentedTab = nil
                            }
                        }
                    ) {
                        DrawerDetailRouter(tab: tab, context: context)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(drawerBg.ignoresSafeArea())
        .onChange(of: isOpen) { open in
            // 抽屉关闭时清空二级页状态，保证下次打开是干净列表
            if !open { presentedTab = nil }
        }
    }

    private func drawerList(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题
            HStack {
                Text("DAYFOLD")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(drawerAccent)
                    .tracking(2)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 24)

            // 第一组
            DrawerGroup(
                title: "日记",
                tabs: group1,
                presentedTab: $presentedTab
            )

            Spacer()

            // 底部分隔线
            Rectangle()
                .fill(drawerDivider)
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            // 第二组（固定底部）
            DrawerGroup(
                title: "更多",
                tabs: group2,
                presentedTab: $presentedTab
            )
            .padding(.bottom, 32)
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(drawerBg.ignoresSafeArea())
    }
}

private struct DrawerGroup: View {
    let title: String
    let tabs: [SidebarTab]
    @Binding var presentedTab: SidebarTab?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 组标题
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(drawerGroupLabel)
                .tracking(1.5)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            // 行列表
            VStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    DrawerRow(tab: tab) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            presentedTab = tab
                        }
                    }

                    if tab != tabs.last {
                        Divider()
                            .background(drawerDivider)
                            .padding(.leading, 58)
                    }
                }
            }
        }
    }
}

private struct DrawerRow: View {
    let tab: SidebarTab
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(drawerText)
                    .frame(width: 22)

                Text(tab.label)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(drawerText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(drawerDivider)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
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
    DrawerView(
        selectedTab: .constant(.list),
        isOpen: .constant(true),
        context: CoreDataStack.shared.viewContext
    )
    .frame(width: 300)
}
