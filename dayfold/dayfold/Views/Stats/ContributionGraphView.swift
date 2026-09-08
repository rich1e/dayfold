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
        // 每个 Text 给一个 cellSize 宽的"对齐槽"，但允许文字向左溢出不被截断
        HStack(alignment: .center, spacing: cellSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { idx, week in
                let prevWeek: [Date?]? = idx > 0 ? weeks[idx - 1] : nil
                Text(monthLabel(for: week, previousWeek: prevWeek))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(theme.textSecondary)
                    .fixedSize()
                    .frame(width: cellSize, alignment: .leading)
                    .id(idx)
            }
        }
        .frame(height: rowHeight, alignment: .leading)
    }

    /// 仅在该列是某月第一周（且与上一列月不同）时显示 "M月"
    private func monthLabel(for week: [Date?], previousWeek: [Date?]?) -> String {
        guard let firstDay = week.compactMap({ $0 }).first else { return "" }
        let cal = Calendar.current
        let day = cal.component(.day, from: firstDay)
        // 只在月初第 1 周（1-7 号）才可能是月份标签
        guard day <= 7 else { return "" }
        // 若上一列存在且同一月，不重复显示
        if let prevFirst = previousWeek?.compactMap({ $0 }).first,
           isSameMonth(prevFirst, firstDay, calendar: cal) {
            return ""
        }
        let f = DateFormatter()
        f.dateFormat = "M月"
        return f.string(from: firstDay)
    }

    private func isSameMonth(_ a: Date, _ b: Date, calendar: Calendar) -> Bool {
        let ca = calendar.component(.year, from: a)
        let cb = calendar.component(.year, from: b)
        if ca != cb { return false }
        return calendar.component(.month, from: a) == calendar.component(.month, from: b)
    }

    // MARK: - Weekday labels

    private struct WeekdayLabel: Identifiable {
        let id: Int              // 0..6 行索引
        let text: String         // 空字符串表示占位
        let isWeekend: Bool
    }

    private func weekdayLabelsColumn() -> some View {
        VStack(alignment: .leading, spacing: cellSpacing) {
            ForEach(weekdayLabels()) { item in
                if item.text.isEmpty {
                    // 占位行：Color.clear 严格占 cellSize 高度，保证与右侧 7 行 cell 严格对齐
                    Color.clear
                        .frame(width: weekdayLabelsWidth, height: cellSize)
                } else {
                    Text(item.text)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(item.isWeekend ? theme.accentDestructive : theme.textTertiary)
                        .frame(width: weekdayLabelsWidth, height: cellSize, alignment: .leading)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
    }

    /// 按 `Calendar.current.firstWeekday` 排序列顺序；周一/周三/周五正常显示，周六/周日红色显示
    private func weekdayLabels() -> [WeekdayLabel] {
        let firstWeekday = Calendar.current.firstWeekday
        // names 按 Calendar weekday 编号索引：1=Sun → index 0, 2=Mon → index 1, ..., 7=Sat → index 6
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        var result: [WeekdayLabel] = []
        for i in 0..<7 {
            // realWeekday: 1..7 对应 Calendar.weekday
            let realWeekday = ((firstWeekday - 1 + i) % 7) + 1
            let isWeekend = (realWeekday == 1 || realWeekday == 7)
            var text = ""
            // 显示 Mon(weekday=2) / Wed(weekday=4) / Fri(weekday=6)，加上周末
            if realWeekday == 2 || realWeekday == 4 || realWeekday == 6
                || realWeekday == 1 || realWeekday == 7 {
                text = "周" + names[realWeekday - 1]
            }
            result.append(WeekdayLabel(id: i, text: text, isWeekend: isWeekend))
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
                                isToday: Calendar.current.isDate(day, inSameDayAs: today)
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
