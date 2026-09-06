import Foundation
import CoreData

@MainActor
final class OnThisDayViewModel: ObservableObject {
    @Published private(set) var groups: [OnThisDayYearGroup] = []  // 倒序,yearDiff 从大到小
    @Published private(set) var totalCount: Int = 0
    @Published private(set) var recentYearDiff: Int = 0  // 最近一年是 K 年前;0 = 无历史

    struct OnThisDayYearGroup: Identifiable {
        let id: ObjectIdentifier
        let yearDiff: Int
        let earliest: Entry
        let count: Int
    }

    private let context: NSManagedObjectContext
    private let calendar: Calendar

    init(context: NSManagedObjectContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func refresh() {
        let now = Date()
        let nowYear = calendar.dateComponents([.year], from: now).year ?? 0
        let nowMonth = calendar.dateComponents([.month], from: now).month ?? 0
        let nowDay = calendar.dateComponents([.day], from: now).day ?? 0

        let req = NSFetchRequest<Entry>(entityName: "Entry")
        req.predicate = NSPredicate(format: "deletedAt == nil")
        let all = (try? context.fetch(req)) ?? []

        let matching = all.filter { e -> Bool in
            guard let created = e.createdAt else { return false }
            if calendar.isDateInToday(created) { return false }
            let comps = calendar.dateComponents([.year, .month, .day], from: created)
            return comps.month == nowMonth && comps.day == nowDay && comps.year != nowYear
        }

        let byYear = Dictionary(grouping: matching) { e -> Int in
            calendar.dateComponents([.year], from: e.createdAt ?? Date()).year ?? 0
        }

        let mapped = byYear.compactMap { (year, entries) -> OnThisDayYearGroup? in
            let diff = nowYear - year
            guard diff >= 1 else { return nil }
            let sorted = entries.sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
            guard let earliest = sorted.first else { return nil }
            return OnThisDayYearGroup(
                id: ObjectIdentifier(earliest),
                yearDiff: diff,
                earliest: earliest,
                count: entries.count
            )
        }
        .sorted { $0.yearDiff > $1.yearDiff }

        groups = mapped
        totalCount = matching.count
        recentYearDiff = mapped.last?.yearDiff ?? 0
    }
}