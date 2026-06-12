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
            ZStack(alignment: .leading) {
                // 底层：抽屉面板（固定左侧，不做动画）
                DrawerView(selectedTab: $selectedTab, isOpen: $drawerOpen)
                    .frame(width: geo.size.width * 0.65)
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
                // 顶部左右按钮 overlay（随内容区一起移动）
                .overlay(alignment: .topLeading) {
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
                    .padding(.top, 8)
                    .padding(.leading, 12)
                }
                .overlay(alignment: .topTrailing) {
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
                        .padding(.top, 8)
                        .padding(.trailing, 12)
                    }
                }
                // 右侧点击区：关闭抽屉
                .overlay {
                    if drawerOpen {
                        Color.black.opacity(0.01) // 透明可点击层
                            .onTapGesture {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                    drawerOpen = false
                                }
                            }
                    }
                }
                // 内容区整体向右偏移
                .offset(x: drawerOffset)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: drawerOpen)
                // 打开时右侧轻微缩放+阴影
                .scaleEffect(
                    x: drawerOpen ? 0.96 : 1.0,
                    y: drawerOpen ? 0.97 : 1.0,
                    anchor: .trailing
                )
                .shadow(
                    color: drawerOpen ? Color.black.opacity(0.35) : Color.clear,
                    radius: drawerOpen ? 20 : 0,
                    x: drawerOpen ? -8 : 0,
                    y: 0
                )
                .ignoresSafeArea(edges: .bottom)
            }
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
