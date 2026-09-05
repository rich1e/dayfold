// Extensions/Theme/WarmLightTheme.swift
import SwiftUI

/// 暖白纸感主题：Day One 风格。浅米色主底 + 深褐主文字。
/// 材质色（surfacePaper*）跨主题保持不变，保证 Notebook 封面视觉一致性。
struct WarmLightTheme: DayfoldTheme {
    // 背景（米白纸系列）
    var backgroundPrimary: Color { Color(hex: "F5F0E8") }
    var backgroundSecondary: Color { Color(hex: "EDE5D8") }
    var backgroundTertiary: Color { Color(hex: "E5DCC8") }
    var backgroundElevated: Color { Color.white }
    var backgroundPressed: Color { Color(hex: "D8CFB8") }

    // 文字（深褐 → 中褐 → 浅褐）
    var textPrimary: Color { Color(hex: "2A2418") }
    var textSecondary: Color { Color(hex: "6A5F4F") }
    var textTertiary: Color { Color(hex: "9A8E78") }
    var textOnAccent: Color { Color.white }

    // 边框
    var dividerPrimary: Color { Color(hex: "D8CFB8") }
    var dividerSubtle: Color { Color(hex: "E5DCC8") }

    // 强调（沉香红 + 深海青）
    var accentPrimary: Color { Color(hex: "C04030") }
    var accentDestructive: Color { Color(hex: "A02818") }
    var controlInactive: Color { Color(hex: "3A8A98") }

    // 效果（浅色背景下 white overlay 应明显，black shadow 应弱）
    var highlightOverlay: Color { Color.white.opacity(0.4) }
    var shadowOverlay: Color { Color.black.opacity(0.15) }

    // 材质（与 WarmDark 同，保证封面视觉一致）
    var surfacePaper: Color { Color(hex: "F0EDE5") }
    var surfacePaperInk: Color { Color(hex: "4A3020") }
    var surfaceLeather: Color { Color(hex: "A85E20") }
}