// ViewModels/StatsViewModel.swift
import Foundation
import CoreData

@MainActor
final class StatsViewModel: ObservableObject {
    struct TagStat: Identifiable {
        let id: NSManagedObjectID
        let tag: Tag
        let count: Int
    }

    @Published private(set) var totalEntries = 0
    @Published private(set) var monthEntries = 0
    @Published private(set) var yearEntries = 0
    @Published private(set) var currentStreak = 0
    @Published private(set) var tagDistribution: [TagStat] = []
    @Published private(set) var mediaRatio: Double = 0
    @Published private(set) var locationRatio: Double = 0

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func refresh() {
        let req = NSFetchRequest<Entry>(entityName: "Entry")
        req.predicate = NSPredicate(format: "deletedAt == nil")
        let entries = (try? context.fetch(req)) ?? []
        let cal = Calendar.current
        let now = Date()

        totalEntries = entries.count
        monthEntries = entries.filter { cal.isDate($0.createdAt ?? Date(), equalTo: now, toGranularity: .month) }.count
        yearEntries  = entries.filter { cal.isDate($0.createdAt ?? Date(), equalTo: now, toGranularity: .year) }.count

        // streak：从今天反向遍历 Set<Date>，遇缺即停
        var days = Set<Date>()
        for e in entries {
            if let d = e.createdAt { days.insert(cal.startOfDay(for: d)) }
        }
        var streak = 0
        var day = cal.startOfDay(for: now)
        while days.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        currentStreak = streak

        let withMedia = entries.filter { !$0.mediaAssetsArray.isEmpty }.count
        let withLoc   = entries.filter { $0.location != nil }.count
        mediaRatio    = totalEntries == 0 ? 0 : Double(withMedia) / Double(totalEntries)
        locationRatio = totalEntries == 0 ? 0 : Double(withLoc)   / Double(totalEntries)

        // 标签分布：遍历所有 tag，统计非软删 entry 数
        let tagReq = NSFetchRequest<Tag>(entityName: "Tag")
        let tags = (try? context.fetch(tagReq)) ?? []
        tagDistribution = tags
            .map { TagStat(id: $0.objectID, tag: $0, count: $0.entriesArray.filter { !$0.isInTrash }.count) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }
}
