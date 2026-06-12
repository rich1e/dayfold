// Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: SidebarTab = .list
    @State private var showingNewEntry = false
    @State private var drawerOpen = false
    @State private var homeListMode = false

    // 内容区向右偏移量：打开时为屏幕宽的 65%
    private var drawerOffset: CGFloat {
        drawerOpen ? UIScreen.main.bounds.width * 0.65 : 0
    }

    var body: some View {
        GeometryReader { geo in
            let drawerWidth = geo.size.width * 0.65
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
                    if selectedTab == .tags {
                        TagsView(context: viewContext)
                            .transition(.paperDrop)
                    }
                    if selectedTab == .timeline {
                        EntryListView(context: viewContext)
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
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "5BC8D8"))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.leading, 12)

                    Spacer()

                    if selectedTab == .list {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                homeListMode.toggle()
                            }
                        } label: {
                            Image(systemName: homeListMode ? "square.grid.2x2" : "list.bullet")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(hex: "5BC8D8"))
                                .frame(width: 44, height: 44)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 12)
                    }
                }
                .frame(width: geo.size.width)
                .offset(x: offset)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: drawerOpen)
                // 垂直对齐到顶部 safe area 内（ZStack 默认居中，需要明确放到顶部）
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, geo.safeAreaInsets.top + 8)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showingNewEntry) {
            EntryEditorView(context: viewContext)
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
