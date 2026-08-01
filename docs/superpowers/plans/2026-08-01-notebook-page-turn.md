# 阶段 E+ · 笔记本封面翻页动效 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) 或 superpowers:executing-plans task-by-task。本计划以 subagent-driven 模式写就——每个 task 一个 implementer subagent + spec/quality 双审 + 阶段 E+ 整分支宽审。Checkbox 用 `- [ ]`。

**Goal:** HomeView 封面墙模式下滑动 / 编程式切换笔记本时,封面 3D 翻页(当前页沿左侧书脊向左翻 + 下一页从右侧翻入 + 阴影同步),1 个 commit 闭环。

**Architecture:** 新建 `NotebookPageTurnModifier.swift`(自定义 `ViewModifier` + `GeometryEffect`);改 `HomeView.swift` 在 `NotebookCoverView` 上挂 `NotebookPageTurnModifier`。**零 schema 改动、零新依赖、不动 ViewModel / Service / 其它 View**。

**Tech Stack:** SwiftUI 3D transforms (`rotation3DEffect` / `GeometryEffect` / `CATransform3D`) + 现有 TabView `.page` style,沿用项目暖色 token。

## 全局约束(全阶段 E+ 不变)

- **commit message** 中文 Conventional Commits(`类型: 描述`);E+8 一个 commit。
- **构建命令**(从 `/Users/rich1e/workspace/code/dayfold/dayfold` 子目录跑):
  ```
  xcodebuild -project dayfold.xcodeproj -scheme dayfold -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
  ```
  必须 `** BUILD SUCCEEDED **`。SourceKit CLI 误报忽略。
- **暖色 token 严格**:不引入新颜色,沿用 `NotebookCoverView` 既有 `spineColor` / `Color(hex:)`。**不引入新颜色**。
- **导航容器**:本仓库全部用 `NavigationView`,不升级 NavigationStack。
- **不引入新依赖**:仅 SwiftUI + Foundation + Core Graphics(`CGFloat` / `CATransform3D` 在 CoreGraphics),不引入第三方动画库。
- **不改动 schema**:`dayfold.xcdatamodeld/` 零修改。
- **不自动 push**:留本地即可,详见 `~/.claude/projects/.../memory/feedback_no-auto-push.md`。
- **文件末尾必须有换行符**(`.swift` 文件标准)。
- **本阶段 E+ 仅 1 个 task(E+8)**,因为 MVP 范围小(1 个新文件 + HomeView 1 处改)。

---

## Task E+8:笔记本封面 3D 翻页动效

**Files:**
- Create: `dayfold/dayfold/Views/Home/NotebookPageTurnModifier.swift`
- Modify: `dayfold/dayfold/Views/HomeView.swift`(L96-112 范围:`TabView` 内 `NotebookCoverView` 加 `.modifier(NotebookPageTurnModifier(...))`)

**Interfaces:**
- Consumes: `NotebookCoverView`、`TabView(selection: $currentIndex)`、`Notebook.coverStyle`(已有)。
- Produces: 封面墙模式左右滑动 / 编程式跳本时,封面 3D 翻页(沿左侧书脊,书脊位置固定)。

### Step 1:新建 NotebookPageTurnModifier.swift

文件:`dayfold/dayfold/Views/Home/NotebookPageTurnModifier.swift`

**注意:`Views/Home/` 目录当前不存在,需要先 `mkdir -p`。**

```swift
// Views/Home/NotebookPageTurnModifier.swift
import SwiftUI
import CoreGraphics

/// 笔记本封面 3D 翻页 modifier。
///
/// 给定当前页 idx、总页数与 currentIndex binding,渲染时:
/// - 当前页(idx == currentIndex):沿左侧书脊向左翻,progress 从 0 → -1,rotation Y 从 0° → -90°,阴影 X 偏移从 0 → -24
/// - 下一页(idx == currentIndex + 1):从右侧翻入,progress 从 1 → 0,rotation Y 从 90° → 0°,阴影 X 偏移从 +24 → 0
/// - 其他页:opacity 0 + rotation 固定(不可见)
struct NotebookPageTurnModifier: ViewModifier {
    let idx: Int
    let total: Int
    @Binding var currentIndex: Int

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .rotation3DEffect(
                rotationAngle,
                axis: (x: 0, y: 1, z: 0),
                anchor: UnitPoint(x: 0.13, y: 0.5),  // 左侧书脊位置(240 宽中 0.26/2 ≈ 0.13)
                perspective: 0.5                       // iOS 18 rotation3DEffect 用 perspective,等价 m34 = -1/perspective
            )
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: 24,
                x: shadowX,
                y: 16
            )
            .transition(.identity)  // 禁用 TabView 自带 transition,避免与 3D 冲突
    }

    // MARK: - 计算属性

    /// 该页相对 currentIndex 的位置差
    private var diff: Int { idx - currentIndex }

    /// 旋转角度(.degrees)
    private var rotationAngle: Angle {
        switch diff {
        case 0:    return .degrees(0)        // 当前页(初始 / 翻完归位)
        case 1:    return .degrees(90)       // 下一页(从右待翻入)
        case -1:   return .degrees(-90)      // 上一页(已翻出)
        default:   return diff > 0 ? .degrees(90) : .degrees(-90)
        }
    }

    private var opacity: Double {
        switch diff {
        case 0, 1, -1:  return 1.0
        default:        return 0.0
        }
    }

    private var shadowOpacity: Double {
        diff == 0 ? 0.55 : 0.0
    }

    private var shadowX: CGFloat {
        diff == 0 ? 0 : (diff == 1 ? 24 : -24)
    }
}

extension View {
    /// 快捷应用翻页 modifier(total 必须 ≥ 1;total ≤ 1 时 modifier 等价无操作)
    func notebookPageTurn(idx: Int, total: Int, currentIndex: Binding<Int>) -> some View {
        self.modifier(NotebookPageTurnModifier(idx: idx, total: total, currentIndex: currentIndex))
    }
}
```

> **关键技术点**:
> - iOS 17+ 的 `rotation3DEffect(_:axis:anchor:perspective:)` 用 `perspective: CGFloat` 参数,等价 `m34 = -1 / perspective`(本轮用 `perspective: 0.5`)。
> - `anchor: UnitPoint(x: 0.13, y: 0.5)` 沿左侧书脊(spineW ≈ 240 * 0.26 / 2 = 31.2,占封面宽 0.13)。
> - `.transition(.identity)` 抑制 TabView 自带水平滑动 transition,3D rotation 完全自定义控制。
> - 不写 `GeometryEffect` —— 用 `rotation3DEffect` 自带 perspective 已够用,代码更短。
> - 翻页过程 progress 中间态(rotation 0° → -90°):TabView 内部动画曲线驱动,SwiftUI 自动插值,我们不重复实现。

### Step 2:HomeView 接入 notebookPageTurn

文件:`dayfold/dayfold/Views/HomeView.swift`

定位 L96-110(`TabView` 内 `ForEach`),在 `.tag(idx)` 之后、`.padding(.horizontal, 40)` 之前插入 `.notebookPageTurn(idx: idx, total: notebooks.count, currentIndex: $currentIndex)`:

```swift
TabView(selection: $currentIndex) {
    ForEach(Array(notebooks.enumerated()), id: \.element.objectID) { idx, nb in
        NotebookCoverView(notebook: nb)
            .frame(width: 240, height: 340)
            .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 16)   // 既有阴影,可保留(被 modifier 覆盖)
            .tag(idx)
            .notebookPageTurn(idx: idx, total: notebooks.count, currentIndex: $currentIndex)   // 新增
            .padding(.horizontal, 40)
            .onTapGesture {
                currentIndex = idx
                withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                    showDetail = true
                }
            }
    }
}
.tabViewStyle(.page(indexDisplayMode: .never))
.frame(height: 380)
```

> **注意**:原 `.shadow(...)`(L100)与 modifier 内 `.shadow(...)` 会**叠加**。建议**保留原 .shadow 不动**,modifier 的 shadow 在 diff != 0 时已经 return 0 opacity,只对当前页生效;原 .shadow 是 ForEach 渲染时所有 NotebookCoverView 都有的固定阴影。两层叠加在 diff != 0 时(只 currentIndex 页有阴影)等于同一个阴影,可接受。
>
> 若 review 时发现双层阴影在单页时偏黑,改为把原 L100 的 `.shadow` 删掉,只留 modifier 内的。

### Step 3:构建 + 提交

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold && xcodebuild ... build 2>&1 | tail -5
```
期望 `** BUILD SUCCEEDED **`。

```bash
cd /Users/rich1e/workspace/code/dayfold
git add dayfold/dayfold/Views/Home/NotebookPageTurnModifier.swift \
        dayfold/dayfold/Views/HomeView.swift
git commit -m "feat(home): 笔记本封面 3D 翻页动效"
```

### 验收点

| # | 项 | 核对路径 |
|---|-----|------|
| E+8.1 | HomeView 封面墙切换有 3D 翻页效果 | 模拟器跑(详见 ⚠️) |
| E+8.2 | 旋转轴沿左侧书脊 | `anchor: UnitPoint(x: 0.13, y: 0.5)` |
| E+8.3 | 翻页过程阴影 X 偏移有变化 | shadowX 计算分支 |
| E+8.4 | 编程式跳本同样走 3D 翻页 | TabView selection binding 驱动 |
| E+8.5 | 列表模式 listMode 不受影响 | 仅改 coverMode 的 TabView |
| E+8.6 | 单本时不报错 / 无副作用 | total ≤ 1 时 modifier 不参与 |
| E+8.7 | 无新依赖 | 仅 SwiftUI + CoreGraphics(CGFloat) |
| E+8.8 | 无 schema 改动 | `git diff` 不动 xcdatamodeld |
| E+8.9 | 暖色 token 严格 | 不引入新颜色,沿用 NotebookCoverView 既有 |
| E+8.10 | xcodebuild BUILD SUCCEEDED | `cd dayfold && xcodebuild ... build 2>&1 \| tail -5` |

---

## Verification(阶段 E+ 完工后核对)

1. **构建**:`xcodebuild ... build` `** BUILD SUCCEEDED **`
2. **运行时**(必须人工跑模拟器,reviewer 无法验证):
   - 模拟器启动 → HomeView 封面墙模式 → 至少 2 本笔记本 → 左右滑动 → **应看到当前页向左翻 + 下一页从右翻入**,书脊位置固定
   - 「+」创建新本 → 自动跳到新本 → **应看到同样的 3D 翻页**(编程式)
   - 「垃圾桶」删本 → 跳到上一本 / 归零 → 动效正常
   - 列表模式(listMode)切换 → ScrollView 行为不变
3. **回归**:阶段 A/B/C/D/E 全部功能仍正常工作(笔记本、编辑器、TagPicker、mood、saveError、TagsView、EntryListView 筛选、PhotoWall 点击、StatsView、SettingsView、On This Day 区块)
4. **schema 验证**:`git diff origin/main -- dayfold.xcdatamodeld/` 应为空(零 schema 改动)
5. **阶段 E+ 整体目标**:设计文档「纸质笔记本视觉锚点」验收 — 翻页看着像翻书

## ⚠️ Cannot Verify From Diff(reviewer 必标)

- E+8.1 / E+8.3 / E+8.4 的「看着像翻书」效果只在模拟器运行时才能确认,reviewer 仅能从代码层面验证:
  - `perspective` 与 `anchor` 取值合理
  - `.transition(.identity)` 正确禁用 TabView 自带水平滑动
  - `notebookPageTurn` modifier 在 `idx` 与 `currentIndex` 各种组合下计算正确(单元逻辑层面)
  - TabView 不被破坏(selection 仍能 binding 切换)

真正的「看着像翻书」必须人工跑模拟器 → 用户验收。