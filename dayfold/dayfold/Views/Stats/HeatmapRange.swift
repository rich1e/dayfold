// Views/Stats/HeatmapRange.swift
import Foundation

/// Contribution Graph 时间范围枚举
///
/// - `month`        30 天
/// - `threeMonths`  90 天
/// - `sixMonths`    180 天
/// - `year`         365 天（默认）
enum HeatmapRange: String, CaseIterable, Identifiable, Hashable {
    case month
    case threeMonths
    case sixMonths
    case year

    var id: String { rawValue }

    /// 显示的天数（含今天）
    var dayCount: Int {
        switch self {
        case .month:       return 30
        case .threeMonths: return 90
        case .sixMonths:   return 180
        case .year:        return 365
        }
    }

    /// 切换器显示文本
    var label: String {
        switch self {
        case .month:       return "1M"
        case .threeMonths: return "3M"
        case .sixMonths:   return "6M"
        case .year:        return "1Y"
        }
    }
}
