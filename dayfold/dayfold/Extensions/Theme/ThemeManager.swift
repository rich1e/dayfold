// Extensions/Theme/ThemeManager.swift
import SwiftUI
import Observation

/// 主题标识。三套枚举值与 UserDefaults 存储 key 直接对应，禁止重命名（破坏用户已保存的选择）。
enum ThemeID: String, CaseIterable, Identifiable {
    case warmDark
    case warmLight
    case pureDark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmDark: return "暖色暗调"
        case .warmLight: return "暖色亮调"
        case .pureDark: return "纯黑 OLED"
        }
    }

    /// 对应 ColorScheme。warmDark 和 pureDark 强制暗色，warmLight 跟随系统 light。
    var colorScheme: ColorScheme? {
        switch self {
        case .warmDark, .pureDark: return .dark
        case .warmLight: return .light
        }
    }
}

/// 管理当前选中的主题，切换时实时更新并写入 UserDefaults。
@Observable
final class ThemeManager {
    /// 存储 key。改名会丢用户数据。
    private static let storageKey = "dayfold.theme.id"

    /// 当前主题 ID（持久化字段）。
    var id: ThemeID {
        didSet {
            guard id != oldValue else { return }
            UserDefaults.standard.set(id.rawValue, forKey: Self.storageKey)
            // current 在 didSet 里同步刷新，View 自动重渲
            current = Self.theme(for: id)
        }
    }

    /// 当前主题实例。Theme 切换时直接重新赋值，@Environment(\.theme) 持有协议引用会自动跟新。
    var current: DayfoldTheme

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
            .flatMap(ThemeID.init(rawValue:))
        let resolvedID = stored ?? .warmDark
        self.id = resolvedID
        self.current = Self.theme(for: resolvedID)
    }

    /// 通过 ID 拿主题实例。switch 必须穷举所有 case（编译器会强制）。
    static func theme(for id: ThemeID) -> DayfoldTheme {
        switch id {
        case .warmDark: return WarmDarkTheme()
        case .warmLight: return WarmLightTheme()
        case .pureDark: return PureDarkTheme()
        }
    }
}

// MARK: - 全局单例

extension ThemeManager {
    /// 全局单例。Settings 页等需要直接修改 id 的场景使用。
    /// App 启动时已由 dayfoldApp 持有，所有视图共享同一份主题状态。
    static let shared = ThemeManager()
}
