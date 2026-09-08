// Views/Stats/HeatmapPalette.swift
import SwiftUI

/// 5 阶强度等级
enum HeatmapLevel: Int, CaseIterable {
    case empty = 0
    case low = 1
    case mid = 2
    case high = 3
    case max = 4
}

/// amber 5 阶调色板，与 WarmDarkTheme.accentPrimary (#E05A3A) 同色系
enum HeatmapPalette {
    /// level 0..4 五阶
    static let amber: [Color] = [
        Color(red: 0.10, green: 0.09, blue: 0.07),
        Color(red: 0.22, green: 0.13, blue: 0.05),
        Color(red: 0.45, green: 0.22, blue: 0.05),
        Color(red: 0.72, green: 0.36, blue: 0.08),
        Color(red: 0.95, green: 0.50, blue: 0.10)
    ]

    /// 根据当天计数与全局最大值返回对应颜色
    static func color(for count: Int, dataMax: Int) -> Color {
        amber[level(for: count, dataMax: dataMax).rawValue]
    }

    /// 阈值算法：dataMax 等分为 4 段
    /// - 0 → empty
    /// - 1..ceil(max/4) → low
    /// - ceil(max/4)+1..ceil(max/2) → mid
    /// - ceil(max/2)+1..ceil(3·max/4) → high
    /// - 其它 → max
    static func level(for count: Int, dataMax: Int) -> HeatmapLevel {
        guard count > 0 else { return .empty }
        let m = max(1, dataMax)
        let q1 = Int(ceil(Double(m) / 4.0))
        let q2 = Int(ceil(Double(m) / 2.0))
        let q3 = Int(ceil(Double(m) * 3.0 / 4.0))
        if count > q3 { return .max }
        if count > q2 { return .high }
        if count > q1 { return .mid }
        return .low
    }
}
