// Views/Timeline/CalendarView.swift
import SwiftUI

private struct NewEntryDate: Identifiable {
    let id = UUID()
    let date: Date
}

struct CalendarView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @State private var newEntryDate: NewEntryDate?
    @State private var dragOffset: CGFloat = 0

    // 监听条目增删，驱动 dotMap 在新增/删除日记后重算
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)],
        animation: .default
    )
    private var allEntries: FetchedResults<Entry>

    private var dotMap: [Date: [EntryDotType]] {
        _ = allEntries.count
        return viewModel.datesWithEntries(in: viewModel.currentMonth)
    }

    private var selectedEntries: [Entry] {
        guard let date = viewModel.selectedDate else { return [] }
        return viewModel.entriesForDate(date)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 月份导航
                monthHeader

                // 月历网格
                MonthGridView(
                    month: viewModel.currentMonth,
                    dotMap: dotMap,
                    selectedDate: $viewModel.selectedDate
                )
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            if value.translation.width < -50 {
                                viewModel.goToNextMonth()
                            } else if value.translation.width > 50 {
                                viewModel.goToPreviousMonth()
                            }
                        }
                )

                Spacer()
            }
            .background(Color.warmPaper)

            // 底部抽屉覆盖层
            EntryBottomSheet(
                selectedDate: viewModel.selectedDate,
                entries: selectedEntries,
                viewMode: $viewModel.viewMode,
                photoWallScrollTarget: .constant(nil),
                onCreateEntry: { date in
                    newEntryDate = NewEntryDate(date: date)
                }
            )
        }
        .sheet(item: $newEntryDate) { item in
            EntryEditorView(
                entry: nil,
                context: viewContext,
                prefillDate: item.date
            )
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(.warmAccent)
                    .padding(8)
            }

            Spacer()

            Text(monthTitle)
                .font(.warmHeadline)
                .foregroundColor(.warmDark)

            Spacer()

            Button {
                viewModel.goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.warmAccent)
                    .padding(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.warmCream)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: viewModel.currentMonth)
    }
}
