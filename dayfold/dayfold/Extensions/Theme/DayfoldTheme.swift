// Extensions/Theme/DayfoldTheme.swift
import SwiftUI
import UIKit

/// 语义化颜色 token。所有 UI chrome 颜色必须经由此协议访问，禁止在 View 中直接使用 Color(hex:)。
///
/// 三套实现：WarmDarkTheme（默认）、WarmLightTheme、PureDarkTheme。
/// Notebook 封面 / Tag 颜色不在本协议范围（保持数据驱动）。
protocol DayfoldTheme {
    // MARK: - 背景层级（5）
    var backgroundPrimary: Color { get }
    var backgroundSecondary: Color { get }
    var backgroundTertiary: Color { get }
    var backgroundElevated: Color { get }
    var backgroundPressed: Color { get }

    // MARK: - 文字层级（4）
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var textOnAccent: Color { get }

    // MARK: - 边框/分割（2）
    var dividerPrimary: Color { get }
    var dividerSubtle: Color { get }

    // MARK: - 强调色（3）
    var accentPrimary: Color { get }
    var accentDestructive: Color { get }
    var controlInactive: Color { get }

    // MARK: - 效果色（2，直接返回带 alpha 的 Color）
    var highlightOverlay: Color { get }
    var shadowOverlay: Color { get }

    // MARK: - 材质色（3，跨主题固定，不参与深浅反转）
    var surfacePaper: Color { get }
    var surfacePaperInk: Color { get }
    var surfaceLeather: Color { get }
}

// MARK: - EnvironmentKey 注入

struct DayfoldThemeKey: EnvironmentKey {
    static let defaultValue: DayfoldTheme = WarmDarkTheme()
}

extension EnvironmentValues {
    /// 当前主题。View 通过 `@Environment(\.theme) private var theme` 读取。
    /// Preview 中可注入 mock 主题做测试。
    var theme: DayfoldTheme {
        get { self[DayfoldThemeKey.self] }
        set { self[DayfoldThemeKey.self] = newValue }
    }
}

// MARK: - Color ↔ UIColor 桥接

extension Color {
    /// SwiftUI Color → UIKit UIColor，用于 UITextView.textColor 等必须传 UIColor 的 API。
    /// 在主线程调用，避免潜在的颜色解析竞态。
    @MainActor
    var asUIColor: UIColor {
        UIColor(self)
    }
}
