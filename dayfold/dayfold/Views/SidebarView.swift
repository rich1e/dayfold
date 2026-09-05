// Views/SidebarView.swift
import SwiftUI
import CoreData

/// Sidebar 路由枚举
///
/// - `list`: 全部日记 — **仅用于路由**，不在 SidebarView UI 上展示入口，
///           由 HomeView / NotebookDetailView 等其他位置触发进入 EntryListView。
/// - PHOTO ALBUM 风格的装饰类入口（icloud / memories / notifications / privacy /
///   hiddenAlbum / about）在 SidebarView 中展示，但其二级页多为占位或跳系统设置。
enum SidebarTab: String, CaseIterable, Hashable {
    // 路由用（不在 SidebarView UI 中展示）
    case list

    // SidebarView 展示的入口
    case icloud, memories, notifications, privacy, hiddenAlbum
    case stats, trash, about

    var icon: String {
        switch self {
        case .list:         return "book.closed"
        case .icloud:       return "icloud"
        case .memories:     return "sparkles"
        case .notifications: return "bell"
        case .privacy:      return "lock.shield"
        case .hiddenAlbum:  return "eye.slash"
        case .stats:        return "chart.bar"
        case .trash:        return "trash"
        case .about:        return "info.circle"
        }
    }

    var label: String {
        switch self {
        case .list:          return "全部日记"
        case .icloud:        return "iCloud Sync"
        case .memories:      return "Memories"
        case .notifications: return "Notifications"
        case .privacy:       return "Privacy & Face ID"
        case .hiddenAlbum:   return "Hidden Album"
        case .stats:         return "数据统计"
        case .trash:         return "回收箱"
        case .about:         return "About Photos"
        }
    }
}

// 文件内跨文件共享（SidebarView+Detail.swift 引用）
let drawerBg      = Color(red: 0.18, green: 0.18, blue: 0.20)
let drawerRowBg   = Color(red: 0.22, green: 0.22, blue: 0.24)
let drawerDivider = Color(red: 0.28, green: 0.28, blue: 0.30)
let drawerAccent  = Color(red: 0.95, green: 0.45, blue: 0.35)
let drawerText    = Color(red: 0.92, green: 0.92, blue: 0.92)
let drawerBrown   = Color(red: 0.65, green: 0.62, blue: 0.68)
let drawerGroupLabel = Color(hex: "5BC8D8")

/// 单行数据：抽屉中一行菜单项的渲染参数
struct DrawerSettingsRowModel: Identifiable {
    let id: SidebarTab
    let tab: SidebarTab
    let subtitle: String?
    let trailingBadge: String?     // 标题旁的小徽章（如 "PRO"）
    let leadingBadgeColor: Color?  // 头像/徽章底色（默认 drawerAccent）

    init(
        tab: SidebarTab,
        subtitle: String? = nil,
        trailingBadge: String? = nil,
        leadingBadgeColor: Color? = nil
    ) {
        self.id = tab
        self.tab = tab
        self.subtitle = subtitle
        self.trailingBadge = trailingBadge
        self.leadingBadgeColor = leadingBadgeColor
    }
}

/// 设置入口行（占位，外观主题切换改为在 SettingsView 顶部加 Section）
private struct SettingsEntryModel {
    let icon: String
    let label: String
}

struct DrawerView: View {
    @Binding var selectedTab: SidebarTab
    @Binding var isOpen: Bool
    let context: NSManagedObjectContext
    @EnvironmentObject var securityManager: SecurityManager

    @State private var presentedTab: SidebarTab?
    @StateObject private var statsVM: StatsViewModel

    init(selectedTab: Binding<SidebarTab>, isOpen: Binding<Bool>, context: NSManagedObjectContext) {
        self._selectedTab = selectedTab
        self._isOpen = isOpen
        self.context = context
        _statsVM = StateObject(wrappedValue: StatsViewModel(context: context))
    }

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
                        DrawerDetailRouter(
                            tab: tab,
                            context: context,
                            securityManager: securityManager
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(drawerBg.ignoresSafeArea())
        .onAppear { statsVM.refresh() }
        .onChange(of: isOpen) { open in
            // 抽屉关闭时清空二级页状态，保证下次打开是干净列表
            if !open { presentedTab = nil }
        }
    }

    // MARK: - 列表（PHOTO ALBUM 风格：分组卡 + 大写小字组标题）

    private func drawerList(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部标题（无齿轮 icon，与 DAYFOLD 品牌保持纯净）
            VStack(alignment: .leading, spacing: 2) {
                Text("DAYFOLD")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(drawerAccent)
                    .tracking(2)
                Text("Account · Preferences · About")
                    .font(.system(size: 12))
                    .foregroundColor(drawerBrown)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 24)

            // 上半：ACCOUNT + PREFERENCES
            VStack(alignment: .leading, spacing: 20) {
                DrawerGroup(title: "ACCOUNT") {
                    DrawerSettingsGroupCard(rows: [
                        DrawerSettingsRowModel(
                            tab: .icloud,
                            subtitle: "On · 12.4 GB of 50 GB",
                            trailingBadge: "PRO"
                        ),
                        DrawerSettingsRowModel(
                            tab: .memories,
                            subtitle: "Curated weekly"
                        )
                    ], presentedTab: $presentedTab)
                }

                DrawerGroup(title: "PREFERENCES") {
                    DrawerSettingsGroupCard(rows: [
                        DrawerSettingsRowModel(
                            tab: .notifications,
                            subtitle: "Memories · Shared albums"
                        ),
                        DrawerSettingsRowModel(
                            tab: .privacy,
                            subtitle: privacySubtitle
                        ),
                        DrawerSettingsRowModel(
                            tab: .hiddenAlbum,
                            subtitle: "Off"
                        ),
                        DrawerSettingsRowModel(
                            tab: .stats,
                            subtitle: statsSubtitle
                        ),
                        DrawerSettingsRowModel(
                            tab: .trash,
                            subtitle: trashSubtitle
                        )
                    ], presentedTab: $presentedTab)
                }
            }
            .padding(.horizontal, 16)

            // 弹性空白：把 ABOUT & 私人推到抽屉底部
            Spacer(minLength: 16)

            // 底部：ABOUT & 私人
            DrawerGroup(title: "ABOUT") {
                DrawerSettingsGroupCard(rows: [
                    DrawerSettingsRowModel(
                        tab: .about,
                        subtitle: aboutSubtitle
                    )
                ], presentedTab: $presentedTab)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(drawerBg.ignoresSafeArea())
    }

    // MARK: - 副值

    private var privacySubtitle: String {
        securityManager.isEnabled
            ? "Require Face ID to unlock"
            : "Disabled"
    }

    private var trashSubtitle: String? {
        let n = trashCount
        return n > 0 ? "\(n) 条" : nil
    }

    private var statsSubtitle: String? {
        let n = statsVM.totalEntries
        return n > 0 ? "\(n) 篇" : nil
    }

    private var aboutSubtitle: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(v) · Build \(b)"
    }

    private var trashCount: Int {
        let req: NSFetchRequest<Entry> = Entry.fetchRequest()
        req.predicate = NSPredicate(format: "deletedAt != nil")
        return (try? context.count(for: req)) ?? 0
    }
}

// MARK: - 组标题（大写小字）

private struct DrawerGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(drawerGroupLabel)
                .tracking(1.5)
                .padding(.horizontal, 8)
            content()
        }
    }
}

// MARK: - 分组卡（一组内多行 + 行间细线分隔）

private struct DrawerSettingsGroupCard: View {
    let rows: [DrawerSettingsRowModel]
    @Binding var presentedTab: SidebarTab?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                DrawerSettingsRow(model: row) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        presentedTab = row.tab
                    }
                }
                if idx != rows.count - 1 {
                    Divider()
                        .background(drawerDivider)
                        .padding(.leading, 52)
                }
            }
        }
        .background(drawerRowBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - 单行（双行布局：图标 + [标题/徽章 + 副值] + chevron）

private struct DrawerSettingsRow: View {
    let model: DrawerSettingsRowModel
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: model.tab.icon)
                    .font(.system(size: 17))
                    .foregroundColor(drawerText)
                    .frame(width: 22)

                // 中间双行：标题（带可选徽章）+ 副值
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.tab.label)
                            .font(.warmBody)
                            .foregroundColor(drawerText)
                            .lineLimit(1)
                        if let badge = model.trailingBadge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(model.leadingBadgeColor ?? Color(hex: "5BC8D8"))
                                )
                        }
                    }
                    if let subtitle = model.subtitle {
                        Text(subtitle)
                            .font(.warmCaption)
                            .foregroundColor(drawerBrown)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(drawerDivider)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isPressed ? drawerBg.opacity(0.4) : Color.clear)
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

// MARK: - 设置入口行（已停用，外观主题切换改为在 SettingsView 顶部加 Section）

#Preview {
    DrawerView(
        selectedTab: .constant(.list),
        isOpen: .constant(true),
        context: CoreDataStack.shared.viewContext
    )
    .environmentObject(SecurityManager())
    .frame(width: 320)
}
