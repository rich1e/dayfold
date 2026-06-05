// Views/Timeline/TimelineView.swift
import SwiftUI
import CoreData

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    @State private var photoWallScrollTarget: UUID?

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
                Group {
                    switch viewModel.viewMode {
                    case .list:
                        TimelineListView()
                    case .calendar:
                        CalendarView(viewModel: viewModel)
                    case .photoWall:
                        PhotoWallView(viewModel: viewModel, scrollTarget: photoWallScrollTarget)
                    }
                }
            }
            .navigationTitle("时间轴")
            .background(Color.warmPaper)
        }
    }
}

#Preview {
    let context = CoreDataStack.shared.viewContext
    TimelineView(context: context)
        .environment(\.managedObjectContext, context)
}
