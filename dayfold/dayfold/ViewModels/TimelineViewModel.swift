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
    @Published var selectedDate: Date?

    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

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

        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch entries: \(error)")
            return []
        }
    }

    func datesWithEntries(in month: Date) -> Set<Date> {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return []
        }

        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt <= %@",
            startOfMonth as NSDate,
            endOfMonth as NSDate
        )

        do {
            let entries = try viewContext.fetch(fetchRequest)
            return Set(entries.compactMap { entry in
                guard let date = entry.createdAt else { return nil }
                return calendar.startOfDay(for: date)
            })
        } catch {
            return []
        }
    }
}
