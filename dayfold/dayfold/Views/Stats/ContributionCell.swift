// Views/Stats/ContributionCell.swift
import SwiftUI

/// 单格：圆角矩形 + onTap + accessibilityLabel
/// popover 由 binding 驱动（`selectedDay` 在 StatsView 持有），保证 popover 出现在被点击的 cell 上
struct ContributionCell: View {
    let day: Date
    let count: Int
    let size: CGFloat
    let color: Color
    let isToday: Bool
    @Binding var selectedDay: DaySelection?

    var body: some View {
        let selection = DaySelection(day: day, count: count)
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: size, height: size)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedDay = selection
            }
            .popover(
                item: Binding(
                    get: { selectedDay?.id == selection.id ? selection : nil },
                    set: { newValue in
                        if newValue == nil { selectedDay = nil }
                    }
                ),
                attachmentAnchor: .point(.bottom),
                arrowEdge: .top
            ) { sel in
                DayPopoverContent(day: sel.day, count: sel.count)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityElement()
            .accessibilityLabel(Self.accessibilityLabel(day: day, count: count))
    }

    private static func accessibilityLabel(day: Date, count: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "\(f.string(from: day))，\(count) 篇"
    }
}

/// popover 内容视图（独立类型便于 presentationCompactAdaptation 工作）
private struct DayPopoverContent: View {
    let day: Date
    let count: Int
    @Environment(\.theme) private var theme

    private var formattedDay: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: day)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDay)
                .font(.warmCaption)
                .foregroundColor(theme.textSecondary)
            Text("\(count) 篇")
                .font(.warmHeadline)
                .foregroundColor(theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
