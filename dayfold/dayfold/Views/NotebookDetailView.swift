// Views/NotebookDetailView.swift
import SwiftUI
import CoreData

private enum SheetMode: Identifiable {
    case photos, calendar, newEntry
    var id: Int { hashValue }
}

struct NotebookDetailView: View {
    let notebook: Notebook
    let context: NSManagedObjectContext
    var onNewEntry: () -> Void
    @Binding var isPresented: Bool

    @StateObject private var timelineVM: TimelineViewModel
    @FetchRequest private var entries: FetchedResults<Entry>
    @State private var sheetMode: SheetMode?

    init(notebook: Notebook, context: NSManagedObjectContext, onNewEntry: @escaping () -> Void, isPresented: Binding<Bool>) {
        self.notebook = notebook
        self.context = context
        self.onNewEntry = onNewEntry
        self._isPresented = isPresented
        self._timelineVM = StateObject(wrappedValue: TimelineViewModel(context: context))
        self._entries = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Entry.createdAt, ascending: false)],
            animation: .default
        )
    }

    var latestDate: String {
        guard let date = entries.first?.createdAt else { return "—" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy.MM.dd"
        return fmt.string(from: date)
    }

    var body: some View {
        ZStack {
            Color(hex: "2A2A30").ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "5BC8D8"))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Button { sheetMode = .photos } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(sheetMode == .photos ? Color(hex: "5BC8D8") : Color(hex: "9090A0"))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button { sheetMode = .calendar } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(sheetMode == .calendar ? Color(hex: "5BC8D8") : Color(hex: "9090A0"))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                // 标题区
                VStack(spacing: 4) {
                    Text(notebook.name)
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(Color(hex: "D4A574"))
                        .tracking(3)

                    Text("\(latestDate) / \(entries.count) PHOTOS")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "7A7A88"))
                        .tracking(1)
                }
                .padding(.top, 8)
                .padding(.bottom, 20)

                // 日记列表
                if entries.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "4A4A58"))
                        Text("还没有日记")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "6A6A78"))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(entries) { entry in
                                NavigationLink(destination: EntryDetailView(entry: entry)) {
                                    EntryCard(entry: entry, viewModel: EntryListViewModel(context: context))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
            }

            // 底部 + 按钮
            VStack {
                Spacer()
                Button { sheetMode = .newEntry } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "3C3C44"))
                            .frame(width: 56, height: 56)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Color(hex: "9090A0"))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 48)
            }
        }
        .sheet(item: $sheetMode) { mode in
            switch mode {
            case .photos:
                ZStack {
                    Color(hex: "2A2A30").ignoresSafeArea()
                    PhotoWallView(viewModel: timelineVM)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .calendar:
                ZStack {
                    Color(hex: "2A2A30").ignoresSafeArea()
                    CalendarView(viewModel: timelineVM)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .newEntry:
                EntryEditorView(context: context)
            }
        }
    }
}
