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

/// Contribution Graph 调色板：按 colorScheme 自动选择 amber (dark) 或 gray (light)
enum HeatmapPalette {
    /// dark 主题：amber 5 阶（与 WarmDarkTheme.accentPrimary #E05A3A 同色系）
    static let amberDark: [Color] = [
        Color(red: 0.10, green: 0.09, blue: 0.07),
        Color(red: 0.22, green: 0.13, blue: 0.05),
        Color(red: 0.45, green: 0.22, blue: 0.05),
        Color(red: 0.72, green: 0.36, blue: 0.08),
        Color(red: 0.95, green: 0.50, blue: 0.10)
    ]

    /// light 主题：gray 5 阶（与 light bg #F5F0E8/#EDE5D8 对比清晰可分辨）
    /// 0 最浅（接近 bg 颜色，视觉"空"），4 最深（保留一点暖色作为最强信号）
    static let grayLight: [Color] = [
        Color(red: 0.93, green: 0.91, blue: 0.87),  // ≈ WarmLightTheme.backgroundTertiary
        Color(red: 0.78, green: 0.74, blue: 0.68),
        Color(red: 0.60, green: 0.54, blue: 0.46),
        Color(red: 0.42, green: 0.36, blue: 0.28),
        Color(red: 0.85, green: 0.40, blue: 0.20)   // max 仍保留 accent 暖色作为最强信号
    ]

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

    /// 主 API：根据 colorScheme 选择调色板后取色
    static func color(for count: Int, dataMax: Int, colorScheme: ColorScheme) -> Color {
        let palette = colorScheme == .dark ? amberDark : grayLight
        return palette[level(for: count, dataMax: dataMax).rawValue]
    }

    /// 向后兼容：默认按 dark 模式（旧 API，仅作内部回退）
    static func color(for count: Int, dataMax: Int) -> Color {
        color(for: count, dataMax: dataMax, colorScheme: .dark)
    }
}
