# Dayfold Theme System Design Spec

**Date:** 2026-09-05
**Status:** Draft (待审核)
**Author:** Claude

---

## 1. 目标

为 Dayfold 建立可切换的多主题系统。当前 App 的颜色是写死的暗色暖调（参考 Hardcover），但设计上：
- 色值散落在 12+ 个 View 文件里（约 80 处 `Color(hex:)`）
- 7 个 `Color.warmXxx` token 命名带语义暗示（`warmPaper`），无法跨主题复用
- `UIColor.label` 等动态色在 light 系统下解析为黑色（之前发现的 bug）
- 同色多版本（`#9090A0` / `#8A8A98` / `#7A7A88` 都是"次要文字"）

**本次 PR 完成后：**
1. 全部 UI 颜色通过 `theme.xxx` 访问，零 `Color(hex:)` 残留
2. 提供 3 套主题（默认 Warm Dark + Warm Light + Pure Dark）
3. 用户可在设置页切换，切换实时生效并持久化
4. Notebook 封面 / Tag 颜色保持数据驱动，不归 Theme

---

## 2. 范围与非范围

### 范围内
- 新建 Theme 子系统（协议 + 3 套实现 + ThemeManager）
- 新建 Semantic Color token（~20 个，覆盖所有 UI chrome 用色）
- 重写 `Color+Warm.swift` 为 deprecation 入口
- 新建 Settings 页（主题切换）
- 12 个 View 文件的全量替换
- `dayfoldApp` 入口注入 + 持久化
- `SelectableTextEditor` / `RichTextMarkdownParser` 改为接收 `UIColor` 而非 `.label`

### 非范围（保持现状）
- Notebook 封面 5 种 style（`NotebookCoverStyle` 枚举）—— 数据驱动
- Tag 颜色（`Tag.wrappedColor`）—— 数据驱动
- 用户登录/同步逻辑
- 深浅色以外的其他主题维度（暂时只有这 3 套）
- 主题动画过渡（直接切换，无 fade）
- 用户自定义主题

---

## 3. 架构

```
┌─────────────────────────────────────────────────────────────┐
│  View Layer                                                  │
│  @Environment(\.theme) private var theme                     │
│  .foregroundStyle(theme.textPrimary)                        │
└──────────────────┬──────────────────────────────────────────┘
                   │ 读取
┌──────────────────┴──────────────────────────────────────────┐
│  Theme Protocol (DayfoldTheme)                              │
│  - 20 个 token 属性（Color / 衍生计算属性）                  │
└──────────────────┬──────────────────────────────────────────┘
                   │ 实现
┌──────────────────┴──────────────────────────────────────────┐
│  3 套主题实现                                                │
│  - WarmDarkTheme  (默认，对应当前 warmPaper 色板)            │
│  - WarmLightTheme (暖白纸感)                                 │
│  - PureDarkTheme  (纯黑 OLED)                                │
└──────────────────┬──────────────────────────────────────────┘
                   │ 由
┌──────────────────┴──────────────────────────────────────────┐
│  ThemeManager (@Observable)                                 │
│  - current: DayfoldTheme                                    │
│  - persist 到 UserDefaults                                   │
│  - 注入到 Environment                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Semantic Token 清单（核心接口）

### 4.1 背景层级（5 个）
| Token | 用途 | 当前映射 |
|-------|------|---------|
| `backgroundPrimary` | 主屏底色 | warmPaper `#3C3C44` |
| `backgroundSecondary` | 卡片/面板/键盘工具栏 | warmLight `#434350` |
| `backgroundTertiary` | 弹窗/全屏覆盖（比 primary 更深或更浅一档） | `#2A2A30` |
| `backgroundElevated` | 悬浮按钮/Sheet 头 | warmLight `#434350` |
| `backgroundPressed` | 按钮按下态反馈 | warmGray `#52525F` |

### 4.2 文字层级（4 个）
| Token | 用途 | 当前映射 |
|-------|------|---------|
| `textPrimary` | 主文字 | warmDark `#E8E8EC` |
| `textSecondary` | 次要文字/时间戳 | warmBrown `#9090A0` |
| `textTertiary` | 弱化文字/占位 | `#7A7A88` |
| `textOnAccent` | 强调色上的反色文字 | `.white` |

### 4.3 边框/分割（2 个）
| Token | 用途 | 当前映射 |
|-------|------|---------|
| `dividerPrimary` | 主分割线/边框 | warmCream `#4A4A58` |
| `dividerSubtle` | 弱分割 | `#3A3A42` |

### 4.4 强调色（3 个）
| Token | 用途 | 当前映射 |
|-------|------|---------|
| `accentPrimary` | 主强调（CTA、链接、选中态） | warmAccent `#E05A3A` |
| `accentDestructive` | 删除/危险 | `#C03828` |
| `controlInactive` | 未激活控件（未选中模式图标/抽屉非活动项） | `#5BC8D8` |

> 注：原设计中 `accentSecondary`（青蓝 `#5BC8D8`）实际用作"未选中控件色"而非"次强调"。改为 `controlInactive` 后语义更准，light 主题下不会与主强调色抢视觉焦点。

### 4.5 效果色（2 个，动态色，按当前 bg 反向）
| Token | 用途 | 当前映射 |
|-------|------|---------|
| `highlightOverlay` | 悬浮高光（替代 `Color.white.opacity(0.x)`） | light 主题: white 0.4; dark 主题: white 0.06 |
| `shadowOverlay` | 阴影（替代 `Color.black.opacity(0.x)`） | light 主题: black 0.15; dark 主题: black 0.4 |

### 4.6 材质色（3 个，封面/相册纸感，跟主题走但不参与色调反转）
| Token | 用途 | 当前映射 |
|-------|------|---------|
| `surfacePaper` | 笔记本封面/相册纸面基色 | `#F0EDE5` 系列 |
| `surfacePaperInk` | 纸面深色笔画（缝线、图案） | `#4A3020` / `#4A3828` |
| `surfaceLeather` | 皮革封面渐变 | `#C17A3A → #A85E20` |

> 材质色跨主题保持固定（米白纸 + 皮革棕永远是这个样子），不参与 dark/light 反转。

### 4.7 数据色（不入 Theme 协议，作为常量保留）
- `NotebookCoverStyle.spineColor` 5 种（chevronTeal `#8A8A90` / triangleRed `#C04030` / stripesBlack `#303035` / leatherBrown `#2C1A0A` / diagonalGray `#606065`）
- `Tag.displayColor` 运行时读取 `wrappedColor`

---

## 5. 三套主题的具体色值

### 5.1 WarmDarkTheme（默认，对应当前 App）

| Token | 值 |
|-------|-----|
| backgroundPrimary | `#3C3C44` |
| backgroundSecondary | `#434350` |
| backgroundTertiary | `#2A2A30` |
| backgroundElevated | `#434350` |
| backgroundPressed | `#52525F` |
| textPrimary | `#E8E8EC` |
| textSecondary | `#9090A0` |
| textTertiary | `#7A7A88` |
| textOnAccent | `#FFFFFF` |
| dividerPrimary | `#4A4A58` |
| dividerSubtle | `#3A3A42` |
| accentPrimary | `#E05A3A` |
| controlInactive | `#5BC8D8` |
| accentDestructive | `#C03828` |
| highlightOverlay | white @ 0.06 |
| shadowOverlay | black @ 0.4 |
| surfacePaper | `#F0EDE5` |
| surfacePaperInk | `#4A3020` |
| surfaceLeather | `#A85E20` |

### 5.2 WarmLightTheme（暖白纸感，Day One 风格）

| Token | 值 |
|-------|-----|
| backgroundPrimary | `#F5F0E8`（米白纸） |
| backgroundSecondary | `#EDE5D8`（浅卡其） |
| backgroundTertiary | `#E5DCC8`（更深一档） |
| backgroundElevated | `#FFFFFF` |
| backgroundPressed | `#D8CFB8` |
| textPrimary | `#2A2418`（深褐） |
| textSecondary | `#6A5F4F` |
| textTertiary | `#9A8E78` |
| textOnAccent | `#FFFFFF` |
| dividerPrimary | `#D8CFB8` |
| dividerSubtle | `#E5DCC8` |
| accentPrimary | `#C04030`（沉香红） |
| controlInactive | `#3A8A98`（深海青） |
| accentDestructive | `#A02818` |
| highlightOverlay | white @ 0.4 |
| shadowOverlay | black @ 0.15 |
| surfacePaper | `#F0EDE5`（与暗主题同，让封面看起来一致） |
| surfacePaperInk | `#4A3020` |
| surfaceLeather | `#A85E20` |

### 5.3 PureDarkTheme（纯黑 OLED）

| Token | 值 |
|-------|-----|
| backgroundPrimary | `#000000` |
| backgroundSecondary | `#0A0A0C` |
| backgroundTertiary | `#1A1A20` |
| backgroundElevated | `#16161A` |
| backgroundPressed | `#22222A` |
| textPrimary | `#F0F0F4` |
| textSecondary | `#9A9AA8` |
| textTertiary | `#6A6A78` |
| textOnAccent | `#FFFFFF` |
| dividerPrimary | `#2A2A30` |
| dividerSubtle | `#1A1A22` |
| accentPrimary | `#FF6B47`（比 WarmDark 稍亮，提升黑底对比度） |
| controlInactive | `#6BD4E4` |
| accentDestructive | `#E04838` |
| highlightOverlay | white @ 0.08 |
| shadowOverlay | black @ 0.6 |
| surfacePaper | `#F0EDE5`（保持不变） |
| surfacePaperInk | `#4A3020` |
| surfaceLeather | `#A85E20` |

---

## 6. 文件改动清单

### 6.1 新增文件（7 个）

```
Extensions/Theme/
├── DayfoldTheme.swift                  # 协议定义 + EnvironmentKey
├── ThemeManager.swift                  # @Observable 单例 + 持久化
├── WarmDarkTheme.swift                 # 当前默认色板
├── WarmLightTheme.swift                # 暖白纸感
└── PureDarkTheme.swift                 # 纯黑 OLED

Views/Settings/
└── SettingsView.swift                  # 新增设置页（只含主题切换）
```

### 6.2 修改文件（13 个）

| 文件 | 改动 |
|------|------|
| `Extensions/Color+Warm.swift` | 标记 7 个 warmXxx 为 `@available(*, deprecated)`，引导到 `theme.xxx` |
| `dayfoldApp.swift` | 创建 ThemeManager 并注入；锁定 `.preferredColorScheme(.dark)` 改为跟随主题 |
| `Views/MainTabView.swift` | 11 处 Color(hex:) 替换 |
| `Views/SidebarView.swift` | 替换 + 抽屉菜单新增「设置」入口 |
| `Views/HomeView.swift` | 24 处替换；封面材质色改用 `theme.surfacePaper*` |
| `Views/NotebookDetailView.swift` | 24 处替换 |
| `Views/Entry/TrashView.swift` | 4 处替换 |
| `Views/Entry/EntryEditorView.swift` | 替换（原来用 warmXxx 的也换成 theme） |
| `Views/Entry/Components/SelectableTextEditor.swift` | 接受 `textColor: UIColor` 参数，从 theme 取 |
| `Services/RichTextMarkdownParser.swift` | `defaultTextColor` 改为接受参数 |
| `Views/Common/NotebookPickerSheet.swift` | 6 处替换 |
| `Views/Tags/TagEditorView.swift` | 2 处替换（不含数据驱动色） |
| `Views/Entry/Components/PhotoLibraryPickerView.swift` | 1 处替换 |

> 浅色背景下 PhotoLibraryPickerView 的 `.preferredColorScheme(.dark)` 需要改为跟随 ThemeManager。

### 6.3 不修改文件（数据驱动色豁免）

- `Models/Notebook.swift`（封面枚举）
- `Models/Tag.swift`（Tag 颜色）
- `Views/HomeView.swift` 中所有 `notebook.coverStyle.spineColor.xxx`（数据驱动）
- `Views/Tags/TagEditorView.swift` 中所有 `Color(hex: color)`（用户选的颜色）

---

## 7. 关键设计决策

### 7.1 为何用协议 + EnvironmentKey 而非单例直读
- `@Environment(\.theme)` 在 Preview 测试中可以注入 mock 主题
- 协议隔离保证 View 不依赖具体主题类型
- 未来加主题只需新建文件，View 代码 0 修改

### 7.2 为何 highlightOverlay / shadowOverlay 是 Color 而非纯黑/白
原代码用 `Color.white.opacity(0.25)` 是基于"当前是暗色"的假设。在浅色主题下，white overlay 会过曝；black overlay 又会过暗。token 化后由主题决定最优值。

**API 形态（明确）：** token 直接返回带 alpha 的 `Color`，调用方无需再 `.opacity(...)`：
```swift
// 调用方
.fill(theme.highlightOverlay)   // 已含 alpha，干净
.shadow(color: theme.shadowOverlay, radius: 8)
```
主题内部按需返回 `.white.opacity(0.06)` 或 `.black.opacity(0.15)`。

### 7.3 为何材质色（surfacePaper）不入"主题反转"
Notebook 封面永远是"暖色纸"，不应该在 dark/light 主题下变色 —— 否则同一个笔记本在不同主题下视觉完全不同，破坏品牌一致性。Day One 和 Hardcover 都是这么做的（封面纸感固定，只 chrome 跟随主题）。

### 7.4 为何 `accentPrimary` 在 PureDark 提亮
纯黑底 `#000000` 上 `#E05A3A` 视觉对比度尚可但偏暗。PureDark 用 `#FF6B47` 提升一个档次，在 OLED 屏上更醒目。这与 Apple "elevated" 控件在不同背景下的色阶调整思路一致。

### 7.5 ThemeManager 持久化
- 存储 key: `"dayfold.theme.id"`，值: `"warmDark"` / `"warmLight"` / `"pureDark"`
- 启动时读取，失败 fallback 到 `.warmDark`
- 切换时 `@Observable` 触发所有 `@Environment(\.theme)` View 重新计算

### 7.6 Settings 页设计
```
┌─────────────────────────┐
│ ← 设置                  │
├─────────────────────────┤
│ 外观                     │
│                         │
│ ◉ 暖色暗调（默认）       │
│ ○ 暖色亮调               │
│ ○ 纯黑（OLED）           │
│                         │
│ 数据                     │
│ • 导出全部日记           │
│ • 锁定 App              │
└─────────────────────────┘
```
本次 PR 只实现"外观"3 个 RadioButton；"数据"组为占位（不实现）。

---

## 8. 迁移策略（一步到位，按文件分批 commit）

**commit 1: theme 基础设施**（不替换任何 View）
- 新建 6 个 Theme 文件
- `dayfoldApp` 注入 ThemeManager
- `Color+Warm.swift` 加 deprecation 注释
- 构建通过

**commit 2: 引入 Settings 页**
- 新建 `SettingsView`
- SidebarView 抽屉加设置入口
- 构建通过

**commit 3-13: 按文件替换**（每个 View 一个 commit）
- commit 3: MainTabView
- commit 4: SidebarView（除入口按钮）
- commit 5: NotebookDetailView
- commit 6: HomeView
- commit 7: EntryEditorView
- commit 8: SelectableTextEditor + RichTextMarkdownParser（修 .label bug）
- commit 9: TrashView
- commit 10: NotebookPickerSheet
- commit 11: TagEditorView
- commit 12: PhotoLibraryPickerView
- commit 13: 验证 grep 零 `Color(hex:` 残留 + 最终构建

每个 commit 末尾跑 `xcodebuild build` 验证。

---

## 9. 测试策略

- 视觉验证：模拟器手动切 3 套主题，逐屏截图核对无错色
- 单元测试（轻量）：ThemeManager 持久化往返测试
- 回归点：之前发现的 `.label` bug 修复后，在 light 模式下正文字体仍为深色 —— 因为 textEditor 的 `textColor` 现在由 theme 传入，warmLight 也用 `#2A2418` 深色，与背景 `#F5F0E8` 对比度足够

---

## 10. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 12 文件全量替换引入 bug | 每文件单独 commit，每文件后跑 build |
| Light 主题下 Notebook 封面/Tag 颜色对比度差 | 材质色跨主题保持固定，但需要视觉验证 |
| Settings 页打断 SidebarView 的"三组卡"设计 | 设置入口作为抽屉头部右上角图标，不破坏主菜单布局 |
| PureDark OLED 全黑底对深色图片显示不利 | 仅 thumbnail 缩略图有图，全黑背景下图片自然凸显 |

---

## 11. 不在本次范围

- 主题切换动画（fade/cross-dissolve）
- 用户自定义主题
- 跟随系统自动切换（App 主题始终由用户设定）
- 主题导入/导出
- 字体主题
