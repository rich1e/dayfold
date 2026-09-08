// Views/Stats/ContributionGraphView.swift
import SwiftUI

/// Contribution Graph：周列布局的热力图，5 阶 amber 调色板
///
/// 布局思路（借鉴 HeatmapKit 周列算法，自写）：
/// - 右侧 ScrollView 内：VStack(month labels / grid) 整体同步横滚
/// - 每个 VStack 由 7 个 ContributionCell 组成（顺序跟随 `Calendar.current.firstWeekday`）
/// - 顶部 month labels（仅在该列首日落在 1/8/15/22/29 时显示 "M月"）
/// - 左侧 weekday labels（周一/周三/周五 三行），与 grid 7 行严格对齐
struct ContributionGraphView: View {
    let data: [Date: Int]
    let range: HeatmapRange
    @Binding var selectedDay: DaySelection?

    @Environment(\.theme) private var theme

    private let cellSpacing: CGFloat = 3
    private let weekdayLabelsWidth: CGFloat = 22
    private let cellSize: CGFloat = 12
    private let rowHeight: CGFloat = 14
    private let rowSpacing: CGFloat = 6

    var body: some View {
        let computed = computeGrid()
        HStack(alignment: .top, spacing: 6) {
            // 左侧：两列对齐 —— 顶部空占位（与 month labels 行同高），下方 weekday labels（与 grid 7 行同高）
            VStack(alignment: .leading, spacing: rowSpacing) {
                Color.clear
                    .frame(width: weekdayLabelsWidth, height: rowHeight)
                weekdayLabelsColumn()
            }

            // 右侧：ScrollView 包含 month labels + grid，整体同步横滚
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: rowSpacing) {
                    monthLabelsRow(weeks: computed.weeks)
                    grid(weeks: computed.weeks, today: computed.today)
                }
                .padding(.horizontal, 2)
            }
            .defaultScrollAnchor(.trailing)
        }
    }

    // MARK: - Month labels

    private func monthLabelsRow(weeks: [[Date?]]) -> some View {
        HStack(alignment: .center, spacing: cellSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { idx, week in
                Text(monthLabel(for: week))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(theme.textTertiary)
                    .frame(width: cellSize, height: rowHeight, alignment: .leading)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .id(idx)
            }
        }
        .frame(height: rowHeight)
    }

    /// 仅在该列首日落在 1/8/15/22/29 时显示 "M月"
    private func monthLabel(for week: [Date?]) -> String {
        guard let firstDay = week.compactMap({ $0 }).first else { return "" }
        let day = Calendar.current.component(.day, from: firstDay)
        let markerDays: Set<Int> = [1, 8, 15, 22, 29]
        guard markerDays.contains(day) else { return "" }
        let f = DateFormatter()
        f.dateFormat = "M月"
        return f.string(from: firstDay)
    }

    // MARK: - Weekday labels

    private func weekdayLabelsColumn() -> some View {
        VStack(alignment: .leading, spacing: cellSpacing) {
            ForEach(Array(weekdayLabels().enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(theme.textTertiary)
                    .frame(width: weekdayLabelsWidth, height: cellSize, alignment: .leading)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    /// 按 `Calendar.current.firstWeekday` 排序列顺序；只显示 周一/周三/周五 三个标签，其余空字符串占位
    private func weekdayLabels() -> [String] {
        let firstWeekday = Calendar.current.firstWeekday
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        var result: [String] = []
        for i in 0..<7 {
            let realIdx = (firstWeekday - 1 + i) % 7
            // 显示 Mon(2) / Wed(4) / Fri(6)
            if realIdx == 2 || realIdx == 4 || realIdx == 6 {
                result.append("周" + names[realIdx])
            } else {
                result.append("")
            }
        }
        return result
    }

    // MARK: - Grid

    private func grid(weeks: [[Date?]], today: Date) -> some View {
        let dataMax = max(1, data.values.max() ?? 0)
        return HStack(alignment: .top, spacing: cellSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: cellSpacing) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, dayOpt in
                        if let day = dayOpt {
                            let count = data[day] ?? 0
                            ContributionCell(
                                day: day,
                                count: count,
                                size: cellSize,
                                color: HeatmapPalette.color(for: count, dataMax: dataMax),
                                isToday: Calendar.current.isDate(day, inSameDayAs: today),
                                selectedDay: $selectedDay
                            )
                        } else {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Grid computation

    private struct ComputedGrid {
        let weeks: [[Date?]]
        let today: Date
    }

    private func computeGrid() -> ComputedGrid {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -range.dayCount + 1, to: today) else {
            return ComputedGrid(weeks: [], today: today)
        }
        let firstWeekday = cal.firstWeekday
        let weekdayOfStart = cal.component(.weekday, from: start)
        let padCount = (weekdayOfStart - firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: padCount)
        var cursor = start
        while cursor <= today {
            days.append(cursor)
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        // 把末尾补齐到 7 的倍数（视觉对齐）
        let remainder = days.count % 7
        if remainder != 0 {
            days.append(contentsOf: Array(repeating: nil as Date?, count: 7 - remainder))
        }

        var weeks: [[Date?]] = []
        var idx = 0
        while idx < days.count {
            weeks.append(Array(days[idx..<min(idx + 7, days.count)]))
            idx += 7
        }
        return ComputedGrid(weeks: weeks, today: today)
    }
}
