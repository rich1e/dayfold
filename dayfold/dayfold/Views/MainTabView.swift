// Views/MainTabView.swift
import SwiftUI
import CoreData

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.theme) private var theme
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
            let offset: CGFloat = drawerOpen ? drawerWidth : 0

            ZStack(alignment: .leading) {
                // 底层：抽屉面板（固定左侧，不做动画）
                DrawerView(
                    selectedTab: $selectedTab,
                    isOpen: $drawerOpen,
                    context: viewContext
                )
                .frame(width: drawerWidth)
                .ignoresSafeArea()

                // 上层：内容区（整体向右滑动）
                ZStack {
                    theme.backgroundPrimary.ignoresSafeArea()

                    if selectedTab == .list {
                        HomeView(
                            context: viewContext,
                            isListMode: $homeListMode,
                            onNewEntry: { showingNewEntry = true }
                        )
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
                    color: drawerOpen ? theme.shadowOverlay : Color.clear,
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
                            .foregroundColor(theme.controlInactive)
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
                                .foregroundColor(theme.controlInactive)
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
            EntryEditorView(context: viewContext, notebook: defaultNotebook)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

private struct PlaceholderView: View {
    let icon: String
    let title: String
    let subtitle: String

    @Environment(\.theme) private var theme

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
}
