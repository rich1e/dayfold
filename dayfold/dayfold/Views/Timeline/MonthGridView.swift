// Views/Timeline/MonthGridView.swift
import SwiftUI

struct MonthGridView: View {
    let month: Date
    let dotMap: [Date: [EntryDotType]]
    @Binding var selectedDate: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(spacing: 0) {
            // 星期标题行
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.warmCaption)
                        .foregroundColor(.warmBrown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .background(Color.warmCream)

            // 日期网格
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            dots: dotMap[Calendar.current.startOfDay(for: date)] ?? [],
                            isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                            isToday: Calendar.current.isDateInToday(date)
                        )
                        .onTapGesture {
                            selectedDate = Calendar.current.startOfDay(for: date)
                        }
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
        }
    }

    // 当月所有日格（含前置空格）
    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: month)
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay)
        else { return [] }

        let weekday = calendar.component(.weekday, from: firstDay) - 1 // 0=日
        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        // 补齐到7的倍数
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

struct DayCell: View {
    let date: Date
    let dots: [EntryDotType]
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.warmAccent.opacity(0.25))
                        .frame(width: 32, height: 32)
                }
                if isSelected {
                    Circle()
                        .stroke(Color.warmDark, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.warmBody)
                    .foregroundColor(isToday ? .warmAccent : .warmDark)
                    .fontWeight(isToday ? .bold : .regular)
            }
            .frame(width: 36, height: 36)

            // 圆点指示器
            dotIndicator
                .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var dotIndicator: some View {
        if dots.isEmpty {
            Color.clear
        } else if dots.count <= 3 {
            HStack(spacing: 2) {
                ForEach(Array(dots.prefix(3).enumerated()), id: \.offset) { _, dot in
                    Circle()
                        .fill(dot == .photo ? Color.warmAccent : Color.warmBrown)
                        .frame(width: 5, height: 5)
                }
            }
        } else {
            Text("\(dots.count)+")
                .font(.system(size: 8))
                .foregroundColor(.warmBrown)
        }
    }
}
