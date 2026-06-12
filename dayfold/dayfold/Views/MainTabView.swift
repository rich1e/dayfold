// Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: SidebarTab = .list
    @State private var showingNewEntry = false
    @State private var drawerOpen = false
    @State private var homeListMode = false  // false=封面视图, true=列表视图

    var body: some View {
        ZStack(alignment: .leading) {
            // 内容区（全屏）
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
            // 顶部左右两个按钮
            .overlay(alignment: .topLeading) {
                // 左上：齿轮 → 打开抽屉
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        drawerOpen = true
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
                // 右上：切换封面↔列表视图（仅在 HomeView 时显示）
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
                } else {
                    // 其他 Tab 显示菜单图标（备用）
                    EmptyView()
                }
            }

            // 遮罩层
            if drawerOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            drawerOpen = false
                        }
                    }
                    .transition(.opacity)
            }

            // 抽屉面板
            if drawerOpen {
                DrawerView(selectedTab: $selectedTab, isOpen: $drawerOpen)
                    .frame(width: UIScreen.main.bounds.width * 0.75)
                    .ignoresSafeArea()
                    .transition(.move(edge: .leading))
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 6, y: 0)
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
