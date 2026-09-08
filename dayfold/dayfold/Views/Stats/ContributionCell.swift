// Views/Stats/ContributionCell.swift
import SwiftUI

/// 单格：圆角矩形 + tap 触发自身 popover
/// popover 内部状态由 cell 持有，避免跨视图 binding 导致的渲染循环
struct ContributionCell: View {
    let day: Date
    let count: Int
    let size: CGFloat
    let color: Color
    let isToday: Bool

    @State private var isPopoverPresented: Bool = false

    var body: some View {
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
                isPopoverPresented = true
            }
            .popover(
                isPresented: $isPopoverPresented,
                attachmentAnchor: .point(.bottom),
                arrowEdge: .top
            ) {
                DayPopoverContent(day: day, count: count)
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
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(theme.textSecondary)
            Text("\(count) 篇")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
