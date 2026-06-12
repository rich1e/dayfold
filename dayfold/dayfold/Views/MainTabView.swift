// Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: SidebarTab = .timeline
    @State private var showingNewEntry = false

    var body: some View {
        HStack(spacing: 0) {
            // 侧边导航栏
            SidebarView(selectedTab: $selectedTab) {
                showingNewEntry = true
            }

            // 内容区域
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
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $showingNewEntry) {
            EntryEditorView(context: viewContext)
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
