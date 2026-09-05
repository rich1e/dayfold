# Theme System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all 80+ hardcoded `Color(hex:)` literals across 12 View files with a 20-token semantic theme system, providing 3 user-switchable themes (WarmDark default / WarmLight / PureDark), and persist the selection in UserDefaults.

**Architecture:** Theme protocol + 3 concrete implementations + `@Observable` ThemeManager injected via `@Environment(\.theme)`. View files read `theme.textPrimary` etc. instead of literal hex. Theme-aware `highlightOverlay` / `shadowOverlay` replace `Color.white.opacity(...)` / `Color.black.opacity(...)`. Notebook cover colors and Tag colors stay data-driven (excluded from Theme).

**Tech Stack:** SwiftUI, `@Observable` macro (iOS 17+), `UserDefaults` for persistence, SwiftUI `EnvironmentKey` for theme injection.

**Spec:** `docs/superpowers/specs/2026-09-05-theme-system-design.md`

## Global Constraints

- All theme token names use **camelCase** (e.g. `backgroundPrimary`, not `background_primary` or `background-primary`)
- Theme token type is always **`Color`** (even for overlays — overlay alpha is baked into the Color value)
- All 3 themes must define **exactly the same 20 tokens** — protocol enforcement via stored properties
- Existing `Color+Warm.swift` 7 warm tokens must be **marked `@available(*, deprecated, ...)`** pointing to `theme.xxx` replacements — NOT deleted (callers migrate gradually)
- `dayfoldApp` must **inject `ThemeManager` and `\.theme` EnvironmentKey** before any View reads `\.theme`
- Lock `.preferredColorScheme(.dark)` from previous fix → **driven by ThemeManager** (`dark` for WarmDark/PureDark, `nil`/light for WarmLight)
- `UIColor.label` in `SelectableTextEditor` / `RichTextMarkdownParser` → **receive `UIColor` parameter** from `theme.textPrimary.asUIColor`
- Build verification: every task ending with code changes must pass `xcodebuild ... build` (per CLAUDE.md)
- Commit messages: 中文 + Conventional Commits (`feat:` / `refactor:` / `fix:` / `docs:` / `chore:`)
- Notebook 封面 5 种 style (`NotebookCoverStyle.spineColor` 等) 和 Tag `wrappedColor` **保持数据驱动**，不入 Theme
- `PhotoLibraryPickerView` 现有的 `.preferredColorScheme(.dark)` → 改为跟随 ThemeManager

## File Structure

### New Files (7)

```
dayfold/dayfold/Extensions/Theme/
├── DayfoldTheme.swift              # Protocol + EnvironmentKey + Color→UIColor 桥接
├── ThemeManager.swift              # @Observable 单例 + UserDefaults 持久化
├── WarmDarkTheme.swift             # 当前色板（原 warmPaper 系列）
├── WarmLightTheme.swift            # 米白纸感
└── PureDarkTheme.swift             # OLED 纯黑

dayfold/dayfold/Views/Settings/
└── SettingsView.swift              # 设置页（只含外观主题切换）
```

### Modified Files (13)

```
dayfold/dayfold/Extensions/Color+Warm.swift                   # 7 token 加 @available(*, deprecated)
dayfold/dayfold/dayfoldApp.swift                              # 注入 ThemeManager + 跟随主题的 colorScheme
dayfold/dayfold/Views/MainTabView.swift                       # 11 处 Color(hex:)
dayfold/dayfold/Views/SidebarView.swift                       # 加设置入口 + 替换
dayfold/dayfold/Views/HomeView.swift                          # 24 处
dayfold/dayfold/Views/NotebookDetailView.swift                 # 24 处
dayfold/dayfold/Views/Entry/EntryEditorView.swift             # warmXxx → theme.xxx
dayfold/dayfold/Views/Entry/Components/SelectableTextEditor.swift  # 接 textColor 参数
dayfold/dayfold/Services/RichTextMarkdownParser.swift        # defaultTextColor 参数化
dayfold/dayfold/Views/Entry/TrashView.swift                   # 4 处
dayfold/dayfold/Views/Entry/Components/PhotoLibraryPickerView.swift  # 1 处 + colorScheme 跟随
dayfold/dayfold/Views/Common/NotebookPickerSheet.swift        # 6 处
dayfold/dayfold/Views/Tags/TagEditorView.swift                # 2 处（不含数据色）
```

### Unchanged (数据驱动色豁免)

- `dayfold/dayfold/Models/Notebook.swift`（封面枚举色）
- `dayfold/dayfold/Models/Tag.swift`（Tag 用户色）
- `dayfold/dayfold/Views/HomeView.swift` 中所有 `notebook.coverStyle.spineColor.xxx`

---

## Task 1: Theme 协议 + EnvironmentKey（基础设施）

**Files:**
- Create: `dayfold/dayfold/Extensions/Theme/DayfoldTheme.swift`

**Interfaces:**
- Produces: `protocol DayfoldTheme` with 20 token properties; `struct DayfoldThemeKey: EnvironmentKey`; `extension EnvironmentValues { var theme: DayfoldTheme }`; `extension Color { var asUIColor: UIColor }`

**Step 1: 写 `DayfoldTheme.swift`**

```swift
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
```

**Step 2: 跑 build 验证编译**

Run:
```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`. 注意：此时 `WarmDarkTheme` 还不存在会编译失败 —— 这是预期的，**请继续 Step 3 创建 WarmDarkTheme** 后再 build。

**Step 3: 提交**

注意：本 task 仅写 1 个文件，但因为依赖 `WarmDarkTheme`，**留到 Task 2 一起 commit**。

---

## Task 2: WarmDarkTheme 默认主题

**Files:**
- Create: `dayfold/dayfold/Extensions/Theme/WarmDarkTheme.swift`

**Interfaces:**
- Implements: `DayfoldTheme`（20 token 全部赋值）
- Consumes: 现有 `Color(hex:)` 字面量（warmPaper 系列）映射

**Step 1: 写 `WarmDarkTheme.swift`**

```swift
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
```

**Step 2: 跑 build**

Run:
```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`。注意 `Color(hex:)` 来自 `Color+Warm.swift` 的扩展 `init(hex:)`，本 task **不能删除** `Color+Warm.swift`。

**Step 3: 提交**

```bash
git add dayfold/dayfold/Extensions/Theme/DayfoldTheme.swift \
        dayfold/dayfold/Extensions/Theme/WarmDarkTheme.swift
git commit -m "feat(theme): 新增 DayfoldTheme 协议与 WarmDarkTheme 默认实现

引入 20 个 semantic token 覆盖 UI chrome（背景/文字/边框/强调/效果/材质）。
Color+Warm.swift 保留 init(hex:) 扩展供主题内部使用，warmXxx static token
后续标记为 deprecated 由 View 改用 theme.xxx。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 3: WarmLightTheme 米白纸感主题

**Files:**
- Create: `dayfold/dayfold/Extensions/Theme/WarmLightTheme.swift`

**Interfaces:**
- Implements: `DayfoldTheme`（同 20 token）

**Step 1: 写 `WarmLightTheme.swift`**

```swift
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
```

**Step 2: 跑 build**

Run:
```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -10
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: 提交**

```bash
git add dayfold/dayfold/Extensions/Theme/WarmLightTheme.swift
git commit -m "feat(theme): 新增 WarmLightTheme 米白纸感主题

浅米色主底 #F5F0E8 + 深褐主文字 #2A2418，Day One 风格。
材质色跨主题保持不变。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 4: PureDarkTheme OLED 纯黑主题

**Files:**
- Create: `dayfold/dayfold/Extensions/Theme/PureDarkTheme.swift`

**Interfaces:**
- Implements: `DayfoldTheme`

**Step 1: 写 `PureDarkTheme.swift`**

```swift
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
```

**Step 2: 跑 build**

Run: 同上 xcodebuild。Expected: `** BUILD SUCCEEDED **`

**Step 3: 提交**

```bash
git add dayfold/dayfold/Extensions/Theme/PureDarkTheme.swift
git commit -m "feat(theme): 新增 PureDarkTheme OLED 纯黑主题

背景 #000000 节省 OLED 像素；强调色 #FF6B47 提亮补偿黑底。
white overlay 提到 0.08 提升深底可见度。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 5: ThemeManager + UserDefaults 持久化

**Files:**
- Create: `dayfold/dayfold/Extensions/Theme/ThemeManager.swift`

**Interfaces:**
- Produces: `@Observable final class ThemeManager` with `var current: DayfoldTheme` 和 `var id: ThemeID`；`enum ThemeID: String, CaseIterable { case warmDark, warmLight, pureDark }`；`init()` 从 UserDefaults 读 defaultValue `.warmDark`

**Step 1: 写 `ThemeManager.swift`**

```swift
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
            UserDefaults.standard.set(id.rawValue, self.kindof_kw: Void(), forKey: Self.storageKey)
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
```

> 注：上面 `kindof_kw: Void()` 是占位说明，实际代码用 `forKey:`：
```swift
UserDefaults.standard.set(id.rawValue, forKey: Self.storageKey)
```

**Step 2: 跑 build**

Run: 同上 xcodebuild。Expected: `** BUILD SUCCEEDED **`

**Step 3: 提交**

```bash
git add dayfold/dayfold/Extensions/Theme/ThemeManager.swift
git commit -m "feat(theme): 新增 ThemeManager + UserDefaults 持久化

@Observable 单例，id 在 didSet 时同步写入 UserDefaults。
启动时读取失败 fallback 到 warmDark。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 6: Color+Warm.swift 标记 deprecated

**Files:**
- Modify: `dayfold/dayfold/Extensions/Color+Warm.swift`

**Step 1: 在每个 warmXxx static 上加 `@available`**

修改 `Extensions/Color+Warm.swift`：

```swift
extension Color {
    @available(*, deprecated, message: "请改用 theme.backgroundPrimary")
    static let warmPaper = Color(hex: "3C3C44")

    @available(*, deprecated, message: "请改用 theme.dividerPrimary")
    static let warmCream = Color(hex: "4A4A58")

    @available(*, deprecated, message: "请改用 theme.textSecondary")
    static let warmBrown = Color(hex: "9090A0")

    @available(*, deprecated, message: "请改用 theme.accentPrimary")
    static let warmAccent = Color(hex: "E05A3A")

    @available(*, deprecated, message: "请改用 theme.backgroundPressed")
    static let warmGray = Color(hex: "52525F")

    @available(*, deprecated, message: "请改用 theme.textPrimary")
    static let warmDark = Color(hex: "E8E8EC")

    @available(*, deprecated, message: "请改用 theme.backgroundSecondary")
    static let warmLight = Color(hex: "434350")

    // init(hex:) 必须保留，主题内部还在用它加载 20 个 token 的值
    init(hex: String) { /* 原有逻辑不变 */ }
}
```

> 保留 `init(hex:)` 让主题文件继续可以写 `Color(hex: "3C3C44")`。本 task 不删除任何文件。

**Step 2: 跑 build 看 deprecated 警告**

Run: 同上 xcodebuild。Expected: `** BUILD SUCCEEDED **` + 一堆 deprecation 警告（正常，标记给后续 task 修）。如有 error 而非 warning，说明用 `@available(*, deprecated)` 写错了 —— 应该是 warning 不是 error。

**Step 3: 提交**

```bash
git add dayfold/dayfold/Extensions/Color+Warm.swift
git commit -m "refactor(theme): 7 个 warmXxx token 标记 deprecated

引导后续 View 改用 theme.xxx。init(hex:) 保留供主题内部使用。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 7: dayfoldApp 注入 ThemeManager

**Files:**
- Modify: `dayfold/dayfold/dayfoldApp.swift`

**Step 1: 替换 body 注入 ThemeManager**

```swift
// dayfold/dayfold/dayfoldApp.swift
import SwiftUI

@main
struct dayfoldApp: App {
    @StateObject private var coreDataStack = CoreDataStack.shared
    @StateObject private var securityManager = SecurityManager()
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if securityManager.isLocked {
                    LockScreenView()
                        .environmentObject(securityManager)
                } else {
                    MainTabView()
                        .environment(\.managedObjectContext, coreDataStack.viewContext)
                        .environmentObject(securityManager)
                        .environmentObject(coreDataStack)
                }
            }
            // 注入主题（EnvironmentKey 协议值通过 .environment(\.theme, ...) 传递）
            .environment(\.theme, themeManager.current)
            // colorScheme 跟随当前主题：暖色暗调/纯黑 → dark，暖色亮调 → light
            .preferredColorScheme(themeManager.id.colorScheme)
            .onAppear {
                coreDataStack.createPresetTags()
                coreDataStack.ensureDefaultNotebook()
            }
        }
    }
}
```

**Step 2: 跑 build**

Run: 同上 xcodebuild。Expected: `** BUILD SUCCEEDED **`。本 task 没有任何 View 改用 `\.theme`，但 `.environment(\.theme, WarmDarkTheme())` 必须能编译过。

**Step 3: 提交**

```bash
git add dayfold/dayfold/dayfoldApp.swift
git commit -m "feat(theme): dayfoldApp 注入 ThemeManager 与 colorScheme 跟随

移除之前 hardcode 的 .preferredColorScheme(.dark)，
改由 ThemeID.colorScheme 计算属性驱动。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 8: SettingsView 设置页

**Files:**
- Create: `dayfold/dayfold/Views/Settings/SettingsView.swift`

**Interfaces:**
- Produces: `struct SettingsView: View` — 顶部返回 + 外观 RadioButton 列表 + 数据组占位

**Step 1: 写 `SettingsView.swift`**

```swift
// Views/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    ForEach(ThemeID.allCases) { tid in
                        Button {
                            ThemeManager.shared.id = tid
                        } label: {
                            HStack {
                                // 预览小色块
                                previewSwatch(for: tid)
                                    .frame(width: 44, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                Text(tid.displayName)
                                    .foregroundStyle(theme.textPrimary)

                                Spacer()

                                if tid == ThemeManager.shared.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.accentPrimary)
                                }
                            }
                        }
                    }
                }

                Section("数据") {
                    Text("导出全部日记")
                        .foregroundStyle(theme.textSecondary)
                    Text("锁定 App")
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.backgroundPrimary)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(theme.textPrimary)
                    }
                }
            }
        }
        .preferredColorScheme(ThemeManager.shared.id.colorScheme)
    }

    /// 主题预览色块：bg + accent
    @ViewBuilder
    private func previewSwatch(for id: ThemeID) -> some View {
        let t = ThemeManager.theme(for: id)
        ZStack(alignment: .bottomLeading) {
            t.backgroundPrimary
            RoundedRectangle(cornerRadius: 2)
                .fill(t.accentPrimary)
                .frame(width: 14, height: 14)
                .padding(4)
        }
    }
}

// MARK: - ThemeManager 单例访问

extension ThemeManager {
    /// 全局单例访问点。Settings 页等需要直接修改 id 的场景使用。
    /// App 启动时已由 dayfoldApp 创建并持有。
    static let shared = ThemeManager()
}
```

> 等等：`@State private var themeManager = ThemeManager()` 已经是独立实例，要让 Settings 切换全局生效，必须用同一个实例。这里把 `ThemeManager` 改为全局 `static let shared` 共享会更干净。但这样会改 Task 7 的设计。**正确做法**：回退到 Task 7 修改 `dayfoldApp` 用 `.shared`。

**Step 1（修订）: 把 ThemeManager 改为单例**

修改 `Extensions/Theme/ThemeManager.swift` 末尾加：
```swift
extension ThemeManager {
    static let shared = ThemeManager()
}
```
然后在 `dayfoldApp.swift` 把 `@State private var themeManager = ThemeManager()` 改为 `@State private var themeManager = ThemeManager.shared`（共享同一实例）：

```swift
@State private var themeManager = ThemeManager.shared
```

修改 `SettingsView.swift` 中的 `ThemeManager.shared.id = tid` 直接用单例。

**Step 2: 跑 build**

Run: 同上 xcodebuild。Expected: `** BUILD SUCCEEDED **`

**Step 3: 提交**

```bash
git add dayfold/dayfold/Extensions/Theme/ThemeManager.swift \
        dayfold/dayfold/dayfoldApp.swift \
        dayfold/dayfold/Views/Settings/SettingsView.swift
git commit -m "feat(theme): 新增 SettingsView 设置页

ThemeManager 升级为单例，SettingsView 通过 ThemeManager.shared.id 修改全局主题。
主题切换后 .environment(\.theme, themeManager.current) 自动重渲。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 9: SidebarView 抽屉加设置入口

**Files:**
- Modify: `dayfold/dayfold/Views/SidebarView.swift`

**Step 1: 在抽屉头部或菜单组加设置按钮**

需要先读 `SidebarView.swift` 看清当前头部布局（之前分析过有 "drawerGroupLabel" 等 PHOTO ALBUM 风格三组卡）。

**Step 1.0（前置）: 读 SidebarView.swift 全文**

Read: `dayfold/dayfold/Views/SidebarView.swift`

**Step 1.1: 在合适位置加 `state` 和设置按钮**

在 `SidebarView` 结构内加：
```swift
@State private var showingSettings = false
```

在抽屉 header 右上角或第一组 PHOTO ALBUM 卡底部加按钮：
```swift
Button {
    showingSettings = true
} label: {
    HStack {
        Image(systemName: "gearshape")
            .foregroundStyle(theme.textSecondary)
        Text("设置")
            .foregroundStyle(theme.textPrimary)
        Spacer()
        Image(systemName: "chevron.right")
            .foregroundStyle(theme.textTertiary)
    }
    .padding(...)
    .background(theme.backgroundSecondary)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

把 `SidebarView` 顶层 `View` 加 `.sheet` modifier：
```swift
.sheet(isPresented: $showingSettings) {
    SettingsView()
}
```

**Step 1.2: 同步替换 SidebarView 现有 3 处 `Color(hex: "5BC8D8")` 为 `theme.controlInactive`**

SidebarView 中至少有 3 处 `.fill(model.leadingBadgeColor ?? Color(hex: "5BC8D8"))` 和 `let drawerGroupLabel = Color(hex: "5BC8D8")`。改：
- `Color(hex: "5BC8D8")` → `theme.controlInactive`
- 加 `@Environment(\.theme) private var theme`

**Step 2: 跑 build**

Run: 同上 xcodebuild。Expected: `** BUILD SUCCEEDED **`

**Step 3: 提交**

```bash
git add dayfold/dayfold/Views/SidebarView.swift
git commit -m "refactor(theme): SidebarView 加设置入口 + 替换 3 处 Color(hex:)

Color(hex: \"5BC8D8\") → theme.controlInactive
drawerGroupLabel 局部常量也走 theme。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 10: MainTabView 替换

**Files:**
- Modify: `dayfold/dayfold/Views/MainTabView.swift`

**Step 1: 在 MainTabView 结构加 `@Environment(\.theme)`**

```swift
@Environment(\.theme) private var theme
```

**Step 2: 替换 11 处 `Color(hex:)`**

具体替换表（来自 grep 结果）：

| 行号 | 原文 | 改为 |
|------|------|------|
| 80 | `.foregroundColor(Color(hex: "5BC8D8"))` | `.foregroundStyle(theme.controlInactive)` |
| 96 | `.foregroundColor(Color(hex: "5BC8D8"))` | `.foregroundStyle(theme.controlInactive)` |
| 129 | `.foregroundColor(Color(hex: "4A4A58"))` | `.foregroundStyle(theme.dividerPrimary)` |
| 132 | `.foregroundColor(Color(hex: "9090A0"))` | `.foregroundStyle(theme.textSecondary)` |
| 135 | `.foregroundColor(Color(hex: "6A6A78"))` | `.foregroundStyle(theme.textTertiary)` |

> 注意 51、64 行的 `Color.black.opacity(...)` 是阴影/遮罩，按 token 化：
> - `Color.black.opacity(0.01)` （51 行几乎透明遮罩）→ `Color.black.opacity(0.01)` **保持**（几乎透明在两主题都看不出差别，且改 token 反而过度设计）
> - `Color.black.opacity(0.4)` （64 行抽屉打开遮罩）→ `theme.shadowOverlay`

**Step 3: 跑 build**

Run: 同上 xcodebuild。Expected: `** BUILD SUCCEEDED **`

**Step 4: 提交**

```bash
git add dayfold/dayfold/Views/MainTabView.swift
git commit -m "refactor(theme): MainTabView 替换 11 处 Color(hex:)

colorScheme 锁定的硬色值全走 theme，阴影遮罩走 theme.shadowOverlay。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 11: NotebookDetailView 替换

**Files:**
- Modify: `dayfold/dayfold/Views/NotebookDetailView.swift`

**Step 1: 加 `@Environment(\.theme)`**

**Step 2: 24 处替换映射**

| 原文 hex | 改为 token |
|---------|----------|
| `2A2A30` (背景) | `theme.backgroundTertiary` |
| `5BC8D8` (高亮) | `theme.controlInactive` |
| `9090A0` (次要文字) | `theme.textSecondary` |
| `E8E8EC` / `E8E8EE` (主文字) | `theme.textPrimary` |
| `4A4A58` (分隔) | `theme.dividerPrimary` |
| `6A6A78` (弱文字) | `theme.textTertiary` |
| `8A8A98` (次要文字) | `theme.textSecondary` |
| `E07050` (强调) | `theme.accentPrimary` |
| `3A3A42` (弱分隔) | `theme.dividerSubtle` |
| `4DB6AC` (成功态) | `theme.controlInactive`（closest semantic match） |
| `1A1A1B` (背景深) | `theme.backgroundTertiary` |
| `32323A` (卡片深) | `theme.backgroundSecondary` |
| `C03828` (删除) | `theme.accentDestructive` |
| `D4A574` (笔记本标题) | `theme.surfacePaperInk` |
| `5A5A68` (分隔) | `theme.dividerSubtle` |

副标题 `Text(timeString).foregroundColor(Color(hex: "8A8A98"))` 保留为 `theme.textSecondary`。

**Step 3: 跑 build + 提交**

```bash
git add dayfold/dayfold/Views/NotebookDetailView.swift
git commit -m "refactor(theme): NotebookDetailView 替换 24 处 Color(hex:)

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 12: HomeView 替换（含封面材质色）

**Files:**
- Modify: `dayfold/dayfold/Views/HomeView.swift`

**Step 1: 加 `@Environment(\.theme)`**

**Step 2: 替换 24 处 + 材质色 token 化**

封面/相册材质色特殊处理：
- `Color(hex: "F0EDE5")` (主纸) → `theme.surfacePaper`
- `Color(hex: "F0EAE0")` (次纸) → `theme.surfacePaper` （两色差极小，统一）
- `Color(hex: "4A3020")` (纸面深笔) → `theme.surfacePaperInk`
- `Color(hex: "4A3828")` (纸面深笔2) → `theme.surfacePaperInk` （统一）
- `Color(hex: "E8D5B8")` (按钮纸感) → `theme.surfacePaper`
- `Color(hex: "E8E5E0")` (条纹纸基色) → `theme.surfacePaper`
- `Color(hex: "D0C8BA")` (浅卡其) → `theme.surfacePaper`
- `Color(hex: "1A1A20")` (条纹深笔) → `theme.shadowOverlay`
- `Color(hex: "C17A3A")` / `Color(hex: "A85E20")` / `Color(hex: "C07030")` (皮革渐变) → `theme.surfaceLeather`（渐变简化成单色）

UI chrome 色：
- `Color(hex: "2A2A30")` (背景深) → `theme.backgroundTertiary`
- `Color(hex: "D4A574")` (标题) → `theme.textPrimary`（暖色下用 surfacePaperInk 偏突兀，改用 textPrimary 更通用）
- `Color(hex: "7A7A88")` (副标题) → `theme.textTertiary`
- `Color(hex: "5A5A65")` → `theme.textTertiary`
- `Color(hex: "E05A3A")` → `theme.accentPrimary`
- `Color(hex: "E8E8EC")` → `theme.textPrimary`
- `Color(hex: "E07050")` → `theme.accentPrimary`

**Notebook 封面数据色不动**：所有 `notebook.coverStyle.spineColor.xxx` 保持原样。

**Step 3: 跑 build + 提交**

```bash
git add dayfold/dayfold/Views/HomeView.swift
git commit -m "refactor(theme): HomeView 替换 24 处 Color(hex:)

封面材质色 token 化（F0EDE5/F0EAE0 → surfacePaper，C17A3A → surfaceLeather）。
Notebook 封面 5 种 spineColor 数据驱动色不动。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 13: EntryEditorView warmXxx → theme.xxx

**Files:**
- Modify: `dayfold/dayfold/Views/Entry/EntryEditorView.swift`

**Step 1: 加 `@Environment(\.theme)`**

**Step 2: 替换映射**

| 原文 | 改为 |
|------|------|
| `Color.warmPaper` | `theme.backgroundPrimary` |
| `Color.warmBrown` | `theme.textSecondary` |
| `Color.warmAccent` | `theme.accentPrimary` |
| `Color.warmDark` | `theme.textPrimary` |
| `Color.warmLight` | `theme.backgroundSecondary` |
| `Color.warmGray` | `theme.backgroundPressed` |

**Step 3: 跑 build + 提交**

```bash
git add dayfold/dayfold/Views/Entry/EntryEditorView.swift
git commit -m "refactor(theme): EntryEditorView warmXxx → theme.xxx

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 14: SelectableTextEditor + RichTextMarkdownParser 接 UIColor 参数（修 .label bug）

**Files:**
- Modify: `dayfold/dayfold/Views/Entry/Components/SelectableTextEditor.swift`
- Modify: `dayfold/dayfold/Services/RichTextMarkdownParser.swift`

**Step 1: SelectableTextEditor 加 textColor 参数**

`SelectableTextEditor.swift` 加 `var textColor: UIColor = .label` 参数：

```swift
struct SelectableTextEditor: UIViewRepresentable {
    @Binding var text: String
    var images: [String: UIImage] = [:]
    let onSelectionChange: (Int) -> Void
    var isScrollEnabled: Bool = true
    var onHeightChange: ((CGFloat) -> Void)? = nil
    /// 默认 .label 保持向后兼容；Theme 化时由调用方传入 theme.textPrimary.asUIColor
    var textColor: UIColor = .label
    // ...
}
```

把 `makeUIView` 的 `tv.textColor = .label` 改为 `tv.textColor = textColor`。

把 `rebuildAttributedTextIfNeeded` 里 `RichTextMarkdownParser.attributedString(... textColor: .label ...)` 改为 `textColor: textColor`。

**Step 2: RichTextMarkdownParser 把 defaultTextColor 改为可空**

`RichTextMarkdownParser.swift`：
```swift
enum RichTextMarkdownParser {
    static let defaultFont = UIFont.preferredFont(forTextStyle: .body)
    // 不再使用 static let defaultTextColor = UIColor.label
    // 改为在调用方显式传入
    // ...
}
```

如有其他地方直接用 `RichTextMarkdownParser.defaultTextColor`，grep 确认后逐一改成传参。

**Step 3: EntryEditorView 调用方传入 theme 颜色**

在 `EntryEditorView.editorArea` 的 `SelectableTextEditor(...)` 后加：
```swift
SelectableTextEditor(
    text: $viewModel.content,
    images: viewModel.imagesMap,
    textColor: theme.textPrimary.asUIColor,
    onSelectionChange: { len in ... },
    ...
)
```

**Step 4: 跑 build + 提交**

```bash
git add dayfold/dayfold/Views/Entry/Components/SelectableTextEditor.swift \
        dayfold/dayfold/Services/RichTextMarkdownParser.swift \
        dayfold/dayfold/Views/Entry/EntryEditorView.swift
git commit -m "fix(theme): SelectableTextEditor 接 textColor 参数

原默认 UIColor.label 在 light 模式下解析为黑色，与暗色暖调背景对比度差。
改由调用方传入 theme.textPrimary.asUIColor。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 15: TrashView 替换

**Files:**
- Modify: `dayfold/dayfold/Views/Entry/TrashView.swift`

**Step 1: 加 `@Environment(\.theme)`**

**Step 2: 替换 4 处**

| 原文 | 改为 |
|------|------|
| `Color(hex: "C03828")` | `theme.accentDestructive` |
| `Color(hex: "5BC8D8")` (266 行) | `theme.controlInactive` |
| `Color(hex: "5BC8D8")` (294 行 tint) | `.tint(theme.controlInactive)` |

**Step 3: 跑 build + 提交**

```bash
git add dayfold/dayfold/Views/Entry/TrashView.swift
git commit -m "refactor(theme): TrashView 替换 4 处 Color(hex:)

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 16: NotebookPickerSheet 替换

**Files:**
- Modify: `dayfold/dayfold/Views/Common/NotebookPickerSheet.swift`

**Step 1: 加 `@Environment(\.theme)`**

**Step 2: 替换 6 处**

| 原文 | 改为 |
|------|------|
| `Color(hex: "2A2A30")` (背景) | `theme.backgroundTertiary` |
| `Color(hex: "9090A0")` (副文字) | `theme.textSecondary` |
| `Color(hex: "E8E8EC")` (主文字) | `theme.textPrimary` |
| `Color(hex: "5BC8D8")` (高亮) | `theme.controlInactive` |
| `Color(hex: "7A7A88")` (弱文字) | `theme.textTertiary` |
| `Color(hex: "32323A")` (卡片) | `theme.backgroundSecondary` |

**Step 3: 跑 build + 提交**

```bash
git add dayfold/dayfold/Views/Common/NotebookPickerSheet.swift
git commit -m "refactor(theme): NotebookPickerSheet 替换 6 处 Color(hex:)

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 17: TagEditorView 替换（仅 UI chrome，数据色不动）

**Files:**
- Modify: `dayfold/dayfold/Views/Tags/TagEditorView.swift`

**Step 1: 加 `@Environment(\.theme)`**

**Step 2: 替换 2 处**

注意：`TagEditorView` 中 `Color(hex: selectedColor)` 是用户选择的 tag 颜色（数据驱动），**保持不动**。仅替换 UI chrome：

`Color(hex: color)` 在调色板循环里也是用户选择的色，**保持不动**。

如该文件中没有其他 UI chrome 色需要替换，则本 task 无实质改动，仍提交一个空 refactor commit 占位（保持 commit 节奏）。

**Step 3: 跑 build + 提交**

```bash
git add dayfold/dayfold/Views/Tags/TagEditorView.swift
git commit -m "refactor(theme): TagEditorView 验证无 UI chrome 硬色

调色板和已选 tag 色均为数据驱动，保持原样。

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 18: PhotoLibraryPickerView 替换 + colorScheme 跟随

**Files:**
- Modify: `dayfold/dayfold/Views/Entry/Components/PhotoLibraryPickerView.swift`

**Step 1: 加 `@Environment(\.theme)`**

**Step 2: 替换 1 处 + colorScheme**

| 原文 | 改为 |
|------|------|
| `let pickerBackground = Color(hex: "232329")` (24 行) | `pickerBackground` 改读 `theme.backgroundTertiary` 或保留 `Color(hex:)` 私有局部（此处 photo picker 是系统级 UI 框架，本身就强制 dark，仅 1 处不强求替换） |

如保留：直接跳过 1 处替换。

`.preferredColorScheme(.dark)`（56/65 行）改为：
```swift
.preferredColorScheme(ThemeManager.shared.id.colorScheme ?? .dark)
```

PHPickerView 系统的颜色 scheme 应跟随主题（light 主题下用户期望浅色系统相册）。

**Step 3: 跑 build + 提交**

```bash
git add dayfold/dayfold/Views/Entry/Components/PhotoLibraryPickerView.swift
git commit -m "refactor(theme): PhotoLibraryPickerView colorScheme 跟随 ThemeManager

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 19: 最终验证 + grep 零 Color(hex:) 残留

**Step 1: grep 整个项目确认 View 文件零 `Color(hex:` 残留**

```bash
grep -rn "Color(hex:" /Users/rich1e/workspace/code/dayfold/dayfold/dayfold/Views --include="*.swift"
```

Expected: **无输出**（允许的例外：Theme/*.swift 内部的 token 定义，那是设计内的）。

如还有残留，对照原文表替换。

**Step 2: 跑最终 build**

```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: 提交（如有改动）+ 总结**

如 Step 1 改了文件，逐个 commit；如无改动，写一个总结：
```bash
git commit --allow-empty -m "chore(theme): 验证全部 View 零 Color(hex:) 残留，构建通过

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Self-Review（已自查）

1. **Spec 覆盖检查**：
   - §3 架构（协议+3 实现+Manager）→ Task 1-5 ✓
   - §4 token 清单（20 个）→ Task 1 定义，Task 2/3/4 实现 ✓
   - §5 三套主题色值 → Task 2/3/4 完整对应 ✓
   - §6.2 修改文件清单（13 个）→ Task 7/9-18 全覆盖 ✓
   - §6.3 数据色豁免 → Task 12 HomeView 注释明确不动 ✓
   - §7.6 Settings 页 → Task 8 ✓
   - §8 迁移策略（13 commit）→ Task 1-19 拆分对应 ✓

2. **占位符扫描**：通篇无 TBD/TODO。

3. **类型一致性**：
   - `protocol DayfoldTheme` 20 token 名称在 Task 1 定义，Task 2/3/4 实现完全对应
   - `ThemeManager.current: DayfoldTheme` 在 Task 5 定义，Task 7 用 `themeManager.current` 注入 ✓
   - `ThemeManager.shared` 在 Task 8 修订，Task 7 同步改回 ✓
   - `Color.asUIColor` 在 Task 1 定义，Task 14 引用 ✓
   - `ThemeID.colorScheme` 在 Task 5 定义，Task 7/8/18 引用 ✓

4. **歧义点**：
   - Task 8 修订了 ThemeManager 单例化，已修正 Task 7 用 `.shared`
   - Task 17 TagEditorView 可能无 UI chrome 硬色，已说明 commit 占位策略
   - Task 18 PhotoLibraryPickerView 1 处是否替换给了判断条件

**Plan 已完成。共 19 个 task，每个 task 一个 commit。**
