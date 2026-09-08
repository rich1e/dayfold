// ViewModels/StatsViewModel.swift
import Foundation
import CoreData

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var totalEntries = 0
    @Published private(set) var notebookCount = 0
    @Published private(set) var currentStreak = 0
    @Published private(set) var mediaRatio: Double = 0
    @Published private(set) var locationRatio: Double = 0
    @Published private(set) var tagRatio: Double = 0
    /// key 为 startOfDay（Calendar.current.startOfDay(for: entry.createdAt)），value 为当天 entry 数
    @Published private(set) var dailyCounts: [Date: Int] = [:]
    /// 用户可切换；切换不重新 fetch Core Data，仅影响 visibleDailyCounts
    @Published var heatmapRange: HeatmapRange = .year

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// 根据 heatmapRange 过滤 dailyCounts，仅返回范围内（含今天）的日子
    var visibleDailyCounts: [Date: Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let cutoff = cal.date(byAdding: .day, value: -heatmapRange.dayCount + 1, to: today) else {
            return dailyCounts
        }
        return dailyCounts.filter { $0.key >= cutoff }
    }

    /// 渲染到 Contribution Graph 卡片标题右侧
    var streakLabel: String { "连续 \(currentStreak) 天" }

    func refresh() {
        let req = NSFetchRequest<Entry>(entityName: "Entry")
        req.predicate = NSPredicate(format: "deletedAt == nil")
        let entries = (try? context.fetch(req)) ?? []
        let cal = Calendar.current
        let now = Date()

        totalEntries = entries.count

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
        let withTags  = entries.filter { !$0.tagsArray.isEmpty }.count
        mediaRatio    = totalEntries == 0 ? 0 : Double(withMedia) / Double(totalEntries)
        locationRatio = totalEntries == 0 ? 0 : Double(withLoc)   / Double(totalEntries)
        tagRatio      = totalEntries == 0 ? 0 : Double(withTags)  / Double(totalEntries)

        // 笔记本数（Notebook 无软删除，直接 count）
        let nreq: NSFetchRequest<Notebook> = Notebook.fetchRequest()
        notebookCount = (try? context.count(for: nreq)) ?? 0

        // daily counts：startOfDay bucket
        var bucket: [Date: Int] = [:]
        for e in entries {
            if let d = e.createdAt {
                bucket[cal.startOfDay(for: d), default: 0] += 1
            }
        }
        dailyCounts = bucket
    }
}
