// Extensions/Color+Warm.swift
import SwiftUI

extension Color {
    // 深色主题色系
    static let warmPaper = Color(hex: "2E2E33")   // 主背景
    static let warmCream = Color(hex: "3A3A40")   // 分割线/边框
    static let warmBrown = Color(hex: "C8C0B8")   // 次要文字
    static let warmAccent = Color(hex: "E8603A")  // 主强调色（橙红）
    static let warmGray  = Color(hex: "48484F")   // 卡片阴影/禁用
    static let warmDark  = Color(hex: "F0EDE8")   // 主文字（近白）
    static let warmLight = Color(hex: "38383E")   // 卡片/面板背景

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
