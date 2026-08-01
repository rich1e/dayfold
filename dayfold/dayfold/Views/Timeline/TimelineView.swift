// Views/Timeline/TimelineView.swift
import SwiftUI
import CoreData

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    @State private var photoWallScrollTarget: UUID?
    @Environment(\.managedObjectContext) private var viewContext
    @State private var activeSheet: SheetMode?

    private enum SheetMode: Identifiable {
        case detail(Entry)
        case edit(Entry)
        var id: String {
            switch self {
            case .detail(let e): return "detail-\(e.objectID.uriRepresentation())"
            case .edit(let e):   return "edit-\(e.objectID.uriRepresentation())"
            }
        }
    }

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: TimelineViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 视图模式切换
                Picker("视图模式", selection: $viewModel.viewMode) {
                    Label("列表", systemImage: "list.bullet").tag(TimelineViewMode.list)
                    Label("日历", systemImage: "calendar").tag(TimelineViewMode.calendar)
                    Label("照片墙", systemImage: "square.grid.2x2").tag(TimelineViewMode.photoWall)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.warmLight)

                // 内容区域
                ZStack {
                    if viewModel.viewMode == .list {
                        TimelineListView()
                            .transition(.paperDrop)
                    }
                    if viewModel.viewMode == .calendar {
                        CalendarView(viewModel: viewModel)
                            .transition(.paperDrop)
                    }
                    if viewModel.viewMode == .photoWall {
                        PhotoWallView(
                            viewModel: viewModel,
                            scrollTarget: photoWallScrollTarget,
                            onSelectEntry: { entry in activeSheet = .detail(entry) },
                            onEditEntry: { entry in activeSheet = .edit(entry) }
                        )
                            .transition(.paperDrop)
                    }
                }
                .animation(.easeOut(duration: 0.38), value: viewModel.viewMode)
            }
            .navigationTitle("时间轴")
            .background(Color.warmPaper)
            .sheet(item: $activeSheet) { mode in
                switch mode {
                case .detail(let entry):
                    NavigationView { EntryDetailView(entry: entry) }
                        .environment(\.managedObjectContext, viewContext)
                case .edit(let entry):
                    NavigationView { EntryEditorView(entry: entry, context: viewContext) }
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }
}

#Preview {
    let context = CoreDataStack.shared.viewContext
    TimelineView(context: context)
        .environment(\.managedObjectContext, context)
}
