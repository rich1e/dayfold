// ViewModels/TimelineViewModel.swift
import Foundation
import CoreData

enum TimelineViewMode {
    case list
    case calendar
    case photoWall
}

class TimelineViewModel: ObservableObject {
    @Published var viewMode: TimelineViewMode = .list
    @Published var selectedDate: Date? = Calendar.current.startOfDay(for: Date())
    @Published var currentMonth: Date = Calendar.current.startOfDay(for: Date())

    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    // MARK: - 日历辅助

    func entriesForDate(_ date: Date) -> [Entry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        return (try? viewContext.fetch(fetchRequest)) ?? []
    }

    func datesWithEntries(in month: Date) -> [Date: [EntryDotType]] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: month)
        guard let startOfMonth = calendar.date(from: comps),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
        else { return [:] }

        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt <= %@",
            startOfMonth as NSDate,
            endOfMonth as NSDate
        )

        let entries = (try? viewContext.fetch(fetchRequest)) ?? []
        var result: [Date: [EntryDotType]] = [:]
        for entry in entries {
            guard let date = entry.createdAt else { continue }
            let day = calendar.startOfDay(for: date)
            let dot: EntryDotType = entry.mediaAssetsArray.isEmpty ? .text : .photo
            result[day, default: []].append(dot)
        }
        return result
    }

    func goToPreviousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    func goToNextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }

    // MARK: - 照片墙

    var entriesWithPhotos: [Entry] {
        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let all = (try? viewContext.fetch(fetchRequest)) ?? []
        return all.filter { !$0.mediaAssetsArray.isEmpty }
    }
}

enum EntryDotType {
    case photo   // warmAccent
    case text    // warmBrown
}
