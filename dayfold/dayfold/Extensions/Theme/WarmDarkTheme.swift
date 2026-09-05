// Extensions/Theme/WarmDarkTheme.swift
import SwiftUI

/// 默认主题：暖色暗调，对应当前 App 行为。
/// 色值完全沿用 Color+Warm.swift 中的 7 个 warmXxx token，保持视觉一致性。
struct WarmDarkTheme: DayfoldTheme {
    // 背景
    var backgroundPrimary: Color { Color(hex: "3C3C44") }
    var backgroundSecondary: Color { Color(hex: "434350") }
    var backgroundTertiary: Color { Color(hex: "2A2A30") }
    var backgroundElevated: Color { Color(hex: "434350") }
    var backgroundPressed: Color { Color(hex: "52525F") }

    // 文字
    var textPrimary: Color { Color(hex: "E8E8EC") }
    var textSecondary: Color { Color(hex: "9090A0") }
    var textTertiary: Color { Color(hex: "7A7A88") }
    var textOnAccent: Color { Color.white }

    // 边框
    var dividerPrimary: Color { Color(hex: "4A4A58") }
    var dividerSubtle: Color { Color(hex: "3A3A42") }

    // 强调
    var accentPrimary: Color { Color(hex: "E05A3A") }
    var accentDestructive: Color { Color(hex: "C03828") }
    var controlInactive: Color { Color(hex: "5BC8D8") }

    // 效果
    var highlightOverlay: Color { Color.white.opacity(0.06) }
    var shadowOverlay: Color { Color.black.opacity(0.4) }

    // 材质（跨主题固定）
    var surfacePaper: Color { Color(hex: "F0EDE5") }
    var surfacePaperInk: Color { Color(hex: "4A3020") }
    var surfaceLeather: Color { Color(hex: "A85E20") }
}