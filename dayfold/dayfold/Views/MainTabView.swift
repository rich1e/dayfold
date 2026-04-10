// Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        TabView {
            TimelineView(context: viewContext)
                .tabItem {
                    Label("时间轴", systemImage: "clock")
                }

            EntryListView(context: viewContext)
                .tabItem {
                    Label("全部", systemImage: "book.closed")
                }

            TagsView(context: viewContext)
                .tabItem {
                    Label("标签", systemImage: "tag")
                }
        }
        .accentColor(.warmAccent)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
