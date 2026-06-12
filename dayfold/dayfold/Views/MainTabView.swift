// Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: SidebarTab = .timeline
    @State private var showingNewEntry = false
    @State private var drawerOpen = false

    var body: some View {
        ZStack(alignment: .leading) {
            // 内容区（全屏）
            ZStack {
                Color.warmPaper.ignoresSafeArea()

                if selectedTab == .timeline {
                    TimelineView(context: viewContext)
                        .transition(.paperDrop)
                }
                if selectedTab == .list {
                    EntryListView(context: viewContext)
                        .transition(.paperDrop)
                }
                if selectedTab == .tags {
                    TagsView(context: viewContext)
                        .transition(.paperDrop)
                }
            }
            .animation(.easeOut(duration: 0.38), value: selectedTab)
            // 导航栏按钮 + FAB overlay
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        drawerOpen = true
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.warmBrown)
                        .frame(width: 44, height: 44)
                        .background(Color.warmLight.opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
                .padding(.trailing, 16)
            }
            .overlay(alignment: .bottomTrailing) {
                FABButton {
                    showingNewEntry = true
                }
                .padding(.bottom, 32)
                .padding(.trailing, 24)
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
                    .shadow(color: .black.opacity(0.18), radius: 16, x: 4, y: 0)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showingNewEntry) {
            EntryEditorView(context: viewContext)
        }
    }
}

private struct FABButton: View {
    var action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.warmAccent)
                .clipShape(Circle())
                .shadow(color: Color.warmAccent.opacity(0.4), radius: 10, x: 0, y: 4)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
