// Views/MainTabView.swift
import SwiftUI
import CoreData

struct MainTabView: View {
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: SidebarTab = .list
    @State private var showingNewEntry = false
    @State private var drawerOpen = false
    @State private var homeListMode = false

    private var defaultNotebook: Notebook? {
        let request: NSFetchRequest<Notebook> = Notebook.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Notebook.sortOrder, ascending: true)]
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }

    var body: some View {
        GeometryReader { geo in
            let drawerWidth = geo.size.width * 0.85
            // 抽屉打开时,内容区仅向右小偏移,让封面右边缘露出一部分
            // 在抽屉右侧作为 peek 预览,而不是全部居中导致被裁切。
            // 封面宽度 204pt,半宽 102;Drawer 覆盖 85% 屏宽。
            // 设 contentOffset = 64(W/4 略小),让封面中心 x = W/2 + 64 ≈ 屏幕中线偏右,
            // 封面右边缘 ≈ W/2 + 64 + 102 = W/2 + 166 ≈ 屏幕 75% 处,
            // 落在抽屉右边缘(0.85W = 75% W)上,刚好露出约 0 间距。
            // 实际:抽屉右边缘 0.85W;封面右边缘 = W/2 + 64 + 102 = W/2 + 166
            //   露出 peek = W/2 + 166 - 0.85W = 0.15W - 166 + W/2
            // 对 W=440:封面右边缘 386,抽屉右边缘 374,露出 12pt。
            let contentOffset: CGFloat = drawerOpen ? 64 : 0

            ZStack(alignment: .leading) {
                // 底层：内容区（整体向右滑动）
                ZStack {
                    theme.backgroundPrimary.ignoresSafeArea()

                    Group {
                        switch selectedTab {
                        case .list:
                            HomeView(
                                context: viewContext,
                                isListMode: $homeListMode,
                                onNewEntry: { showingNewEntry = true }
                            )
                            .transition(.paperDrop)
                        case .stats:
                            StatsView(context: viewContext)
                                .transition(.paperDrop)
                        default:
                            PlaceholderView(
                                icon: "square.dashed",
                                title: "敬请期待",
                                subtitle: "该功能开发中"
                            )
                        }
                    }
                }
                .animation(.easeOut(duration: 0.38), value: selectedTab)
                // 右侧点击区：关闭抽屉
                .overlay {
                    if drawerOpen {
                        Color.black.opacity(0.01)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                    drawerOpen = false
                                }
                            }
                    }
                }
                // 内容区整体向右偏移(抽屉打开时让 HomeView 中心落在屏幕右侧,留 32pt 间距)
                .offset(x: contentOffset)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: drawerOpen)
                .shadow(
                    color: drawerOpen ? theme.shadowOverlay : Color.clear,
                    radius: drawerOpen ? 20 : 0,
                    x: drawerOpen ? -6 : 0,
                    y: 0
                )
                .ignoresSafeArea(edges: .bottom)

                // 顶层：抽屉面板（绘制在内容之上,挡住内容区的左半部分）
                if drawerOpen {
                    DrawerView(
                        selectedTab: $selectedTab,
                        isOpen: $drawerOpen,
                        context: viewContext
                    )
                    .frame(width: drawerWidth)
                    .ignoresSafeArea()
                    .transition(.move(edge: .leading))
                }

                // 顶部按钮层：独立于 ignoresSafeArea 内容区之上，在安全区内布局
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            drawerOpen.toggle()
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(theme.controlInactive)
                            .frame(width: 56, height: 56)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 4)

                    Spacer()

                    if selectedTab == .list {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                homeListMode.toggle()
                            }
                        } label: {
                            Image(systemName: homeListMode ? "square.grid.2x2" : "list.bullet")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(theme.controlInactive)
                                .frame(width: 56, height: 56)
                                .contentShape(Rectangle())
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 4)
                    }
                }
                .frame(width: geo.size.width)
                .offset(x: contentOffset)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: drawerOpen)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showingNewEntry) {
            EntryEditorView(context: viewContext, notebook: defaultNotebook)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

private struct PlaceholderView: View {
    @Environment(\.theme) private var theme
    let icon: String
    let title: String
    let subtitle: String


    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(theme.dividerPrimary)
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundPrimary.ignoresSafeArea())
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
        .environmentObject(SecurityManager())
}
