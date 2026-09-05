// Extensions/Theme/PureDarkTheme.swift
import SwiftUI

/// 纯黑 OLED 主题：背景 #000000 节省 OLED 像素；强调色 #FF6B47 提亮以补偿黑底。
struct PureDarkTheme: DayfoldTheme {
    var backgroundPrimary: Color { Color.black }
    var backgroundSecondary: Color { Color(hex: "0A0A0C") }
    var backgroundTertiary: Color { Color(hex: "1A1A20") }
    var backgroundElevated: Color { Color(hex: "16161A") }
    var backgroundPressed: Color { Color(hex: "22222A") }

    var textPrimary: Color { Color(hex: "F0F0F4") }
    var textSecondary: Color { Color(hex: "9A9AA8") }
    var textTertiary: Color { Color(hex: "6A6A78") }
    var textOnAccent: Color { Color.white }

    var dividerPrimary: Color { Color(hex: "2A2A30") }
    var dividerSubtle: Color { Color(hex: "1A1A22") }

    var accentPrimary: Color { Color(hex: "FF6B47") }
    var accentDestructive: Color { Color(hex: "E04838") }
    var controlInactive: Color { Color(hex: "6BD4E4") }

    var highlightOverlay: Color { Color.white.opacity(0.08) }
    var shadowOverlay: Color { Color.black.opacity(0.6) }

    var surfacePaper: Color { Color(hex: "F0EDE5") }
    var surfacePaperInk: Color { Color(hex: "4A3020") }
    var surfaceLeather: Color { Color(hex: "A85E20") }
}