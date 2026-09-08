// Views/Stats/ContributionCell.swift
import SwiftUI

/// 单格：圆角矩形 + onTap + accessibilityLabel
struct ContributionCell: View {
    let day: Date
    let count: Int
    let size: CGFloat
    let color: Color
    let isToday: Bool
    let onTap: () -> Void

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
            .onTapGesture(perform: onTap)
            .accessibilityElement()
            .accessibilityLabel(Self.accessibilityLabel(day: day, count: count))
    }

    private static func accessibilityLabel(day: Date, count: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "\(f.string(from: day))，\(count) 篇"
    }
}
