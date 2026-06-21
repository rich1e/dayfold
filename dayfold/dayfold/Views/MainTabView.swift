// Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: SidebarTab = .list
    @State private var showingNewEntry = false
    @State private var showingTrash = false
    @State private var drawerOpen = false
    @State private var homeListMode = false

    private var topInset: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top) ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            let drawerWidth = geo.size.width * 0.85
            let offset: CGFloat = drawerOpen ? drawerWidth : 0

            ZStack(alignment: .leading) {
                // 底层：抽屉面板（固定左侧，不做动画）
                DrawerView(selectedTab: $selectedTab, isOpen: $drawerOpen)
                    .frame(width: drawerWidth)
                    .ignoresSafeArea()

                // 上层：内容区（整体向右滑动）
                ZStack {
                    Color.warmPaper.ignoresSafeArea()

                    if selectedTab == .list {
                        HomeView(
                            context: viewContext,
                            isListMode: $homeListMode,
                            onNewEntry: { showingNewEntry = true }
                        )
                        .transition(.paperDrop)
                    }
                    if selectedTab == .photos {
                        EntryListView(context: viewContext)
                            .transition(.paperDrop)
                    }
                    if selectedTab == .map {
                        MapView(showingNewEntry: $showingNewEntry)
                            .transition(.paperDrop)
                    }
                    if selectedTab == .stats {
                        PlaceholderView(icon: "chart.bar", title: "数据统计", subtitle: "即将推出")
                            .transition(.paperDrop)
                    }
                    if selectedTab == .settings {
                        PlaceholderView(icon: "gearshape", title: "设置", subtitle: "即将推出")
                            .transition(.paperDrop)
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
                // 内容区整体向右偏移（与抽屉宽度完全一致，无缝隙）
                .offset(x: offset)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: drawerOpen)
                .shadow(
                    color: drawerOpen ? Color.black.opacity(0.4) : Color.clear,
                    radius: drawerOpen ? 20 : 0,
                    x: drawerOpen ? -6 : 0,
                    y: 0
                )
                .ignoresSafeArea(edges: .bottom)

                // 顶部按钮层：独立于 ignoresSafeArea 内容区之上，在安全区内布局
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            drawerOpen.toggle()
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Color(hex: "5BC8D8"))
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 8)

                    Spacer()

                    if selectedTab == .list {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                homeListMode.toggle()
                            }
                        } label: {
                            Image(systemName: homeListMode ? "square.grid.2x2" : "list.bullet")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(Color(hex: "5BC8D8"))
                                .frame(width: 48, height: 48)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 8)
                    }
                }
                .frame(width: geo.size.width)
                .offset(x: offset)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: drawerOpen)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, -15)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showingNewEntry) {
            EntryEditorView(context: viewContext)
        }
        .sheet(isPresented: $showingTrash, onDismiss: {
            // 关闭后恢复到 list，避免 drawer 仍高亮 trash
            if selectedTab == .trash { selectedTab = .list }
        }) {
            TrashView()
        }
        .onChange(of: selectedTab) { tab in
            if tab == .trash {
                showingTrash = true
            }
        }
    }
}

private struct PlaceholderView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(Color(hex: "4A4A58"))
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "9090A0"))
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "6A6A78"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.warmPaper.ignoresSafeArea())
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
