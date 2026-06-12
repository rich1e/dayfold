// Extensions/Color+Warm.swift
import SwiftUI

extension Color {
    // 深色主题色系（参考 Hardcover 配色）
    static let warmPaper = Color(hex: "3C3C44")   // 主背景（蓝灰深色）
    static let warmCream = Color(hex: "4A4A58")   // 分割线/边框
    static let warmBrown = Color(hex: "9090A0")   // 次要文字/禁用
    static let warmAccent = Color(hex: "E05A3A")  // 主强调色（橙红）
    static let warmGray  = Color(hex: "52525F")   // 卡片阴影层/禁用背景
    static let warmDark  = Color(hex: "E8E8EC")   // 主文字（近白偏蓝灰）
    static let warmLight = Color(hex: "434350")   // 卡片/面板/行背景

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
