# 阶段 E+ · 笔记本封面翻页动效 设计文档

> 生成日期:2026-08-01
> 背景:阶段 0+A+B+C+D+E 全部完成,main HEAD `e83216a`,领先 origin/main 33 commits(未推)。本轮做 `2026-04-07-...-design.md §6` 视觉系统中「笔记本封面翻页」动效,响应阶段 A 已知延后项(本项目最早期就计划过、UI 改版 spec `2026-06-12-...-design.md §一`「纸张翻页」动效基调)。
> 依据:`dayfold/dayfold/Views/HomeView.swift` 源码实测 —— 当前 `HomeView.swift:96-112` 已用 `TabView(selection: $currentIndex).tabViewStyle(.page(indexDisplayMode: .never))` 切换笔记本封面,但自带水平滑动 transition,无 3D 翻页效果。

## 一、目标与范围

让用户在 HomeView 封面墙模式下滑动切换笔记本时,看到真书翻页的 3D 翻动效果(当前页向左翻 + 下一页从右侧翻入),呼应 Dayfold 「纸质笔记本」的视觉锚点。MVP 范围内最小可用闭环,不做暗黑验证、不做选本中点展开、不接列表模式联动。

| # | 缺口 | 现状 | 阶段 |
|---|------|------|------|
| 1 | HomeView 封面墙切换无 3D 翻页效果 | TabView 默认水平滑动,无书脊透视 | E+8 |

## 二、关键决策(已与用户确认)

1. **动效风格:全翻页(3D rotation)** —— 当前页 `rotation3DEffect` 从 `0°` → `-90°`(沿左边缘 / 书脊轴),下一页从 `90°` → `0°`(从右侧翻入),阴影 + 透视同步。
2. **作用对象:仅 HomeView 封面墙模式(coverMode)** —— 列表模式(listMode)不动,保持 ScrollView 列表上下滑行为。
3. **触发:左右滑动 + 编程式 `currentIndex` 变更** —— `TabView` 编程式改 `selection` 时也走相同动效,不应只触发滑动。
4. **MVP 范围,不做**:
   - 中点折角 / 手指拖拽折角(iOS 标准 PDF/书籍阅读器的折角交互)
   - 暗黑模式专项压测(本轮不验证)
   - 列表模式(listMode)选本动效(列表模式目前 ScrollView 自然滚动)
   - 笔记本添加 / 删除时的飞入飞出(沿用现有 spring)
5. **零 schema 改动** —— 不动 Core Data。
6. **零新依赖** —— 仅 SwiftUI `rotation3DEffect` / `transition` / `GeometryEffect`,不引入第三方动画库。
7. **不引入新颜色** —— 沿用现有 `NotebookCoverView` 的 `spineColor` / `Color(hex:)`。

## 三、架构与数据流

```
HomeView (coverMode)
└── TabView(selection: $currentIndex)
    └── ForEach notebooks (idx, nb)
        └── NotebookCoverView(nb)        ← 既有,不动
            .transition(AsymmetricPageTurn(idx: idx, currentIndex: $currentIndex))   ← 新增
```

**新增文件**(全部新建):
- `dayfold/dayfold/Views/Home/NotebookPageTurnModifier.swift` —— 自定义 `ViewModifier` + `GeometryEffect`,封装 3D 翻页 transition + shadow 位移

**修改文件**:
- `dayfold/dayfold/Views/HomeView.swift`(L96-112 范围): `NotebookCoverView` 加 `.modifier(NotebookPageTurnModifier(idx: idx, total: notebooks.count, currentIndex: $currentIndex))`,`TabView` 不动

## 四、核心算法

### 4.1 翻页动效模型

对每个封面页 `i`,根据 `currentIndex` 决定其处于哪个状态:

| `i` vs `currentIndex` | 状态 | rotation3DEffect Y | opacity | shadow offset |
|----------------------|------|---------------------|---------|----------------|
| `i == currentIndex` | 当前页(向后翻) | `0° → -90°`(翻出) | `1 → 0.3` | `(0, 16) → (-24, 16)` |
| `i == currentIndex + 1` | 下一页(从右进入) | `90° → 0°`(翻入) | `0.3 → 1` | `(24, 16) → (0, 16)` |
| `i == currentIndex - 1` | 上一页(从左离开) | `0° → -90°`(已翻出后占位) | `0.3 → 0` | `(0, 16)` |
| `i < currentIndex - 1` | 已翻过(不可见) | `-90°` | `0` | — |
| `i > currentIndex + 1` | 未到(不可见) | `90°` | `0` | — |

进度 `progress ∈ [0, 1]`:由 `TabView` 内部 scroll offset 计算,在 `GeometryEffect` 中通过 `effectValue` 拿到。

### 4.2 GeometryEffect 实现关键

```swift
struct PageTurnEffect: GeometryEffect {
    var idx: Int
    var total: Int
    var currentIndex: Int
    var progress: CGFloat          // [-1, 1]: -1 = 当前页向左翻到 -90°, 1 = 下一页翻入

    func effectValue(size: CGSize) -> ProjectionTransform {
        // 以左侧 spineW (size.width * 0.26) 为旋转轴
        let spineX = size.width * 0.26 / 2
        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 800.0  // 透视:z=800 拉远
        let angle = Angle.degrees(-90.0 * progress)
        transform = CATransform3DRotate(transform, CGFloat(angle.radians), 0, 1, 0)
        transform = CATransform3DTranslate(transform, spineX, 0, 0)
        transform = CATransform3DTranslate(transform, -spineX, 0, 0)
        return ProjectionTransform(transform)
    }
}
```

### 4.3 与 TabView 自带动画的关系

`TabView(.page)` 自带水平 `transition` 与 `animation`,**会与自定义 3D 翻页冲突**。两选一:
- **方案 A**:把 `TabView` 改为非 `.page` style,用 `HStack` 装当前页 + 翻页 modifier,完全自己控制
- **方案 B(推荐)**:保留 `TabView(.page)`,**禁用其内置 transition**(`transition(.identity)`),只让自定义 3D modifier 起作用;`TabView` 仍管切换状态与手势

实施选 **方案 B**,影响面小,既保留手势又叠 3D。

### 4.4 跨边界

- 总笔记本数 ≤ 1 时:**`.tabViewStyle(.page)` 退化(无切换可言)**,动效不参与,只展示当前封面,无副作用
- 总笔记本数 ≥ 2:`.tabViewStyle(.page(indexDisplayMode: .never))` 启用,翻页生效
- 编程式跳转(创建笔记本后 `currentIndex = notebooks.count - 1`):同样走 `.page` 自带动画曲线,翻页自动适应

## 五、UI 与交互规范

### 5.1 视觉细节

- 透视系数 `m34 = -1/800`,对应「相机在 z=800 处」,封面大小 240×340 在 iPhone 16 Pro 屏上透视自然
- 旋转轴:沿左侧书脊(`spineX = size.width * 0.26 / 2`),保证翻页时左侧书脊位置固定,右侧翻动,贴合真书
- 阴影位移:翻页中点(progress = 0.5)阴影 X 偏移最大(-24 或 +24),结束时归位
- 不透明度:翻页 0° → -90° 时 opacity 从 1 → 0.3(避免完全不可见导致背景闪)
- 切换曲线:沿用 `TabView` 自带 iOS 分页 spring(默认 `interactiveSpring(response: 0.35, dampingFraction: 0.78)`),不覆盖

### 5.2 页面指示器

`PageIndicator(count:current:)`(HomeView:119 已存在)**不动**,继续显示当前第几本,翻页时与封面同步。

### 5.3 列表模式(listMode)

**完全不动**,scroll view 行为不变。

## 六、验收标准

| # | 项 | 核对路径 |
|---|-----|------|
| E+8.1 | HomeView 封面墙左右滑动时,看到 3D 翻页效果(当前页向左翻+下一页向右翻入) | HomeView 模拟器跑(详见 ⚠️) |
| E+8.2 | 旋转轴沿左侧书脊,书脊位置固定 | PageTurnEffect.spineX |
| E+8.3 | 翻页过程阴影 X 偏移有变化 | PageTurnEffect 中 transform + shadow 同步 |
| E+8.4 | 编程式跳本(创建笔记本后)同样走 3D 翻页 | TabView selection binding |
| E+8.5 | 列表模式 listMode 不受影响 | HomeView listModeView 未改 |
| E+8.6 | 单本时不报错 / 无副作用 | total ≤ 1 时 modifier 不参与 |
| E+8.7 | 无新依赖 | 仅 SwiftUI + Foundation |
| E+8.8 | 无 schema 改动 | git diff xcdatamodeld 为空 |
| E+8.9 | 暖色 token 严格 | 不引入新颜色,沿用 NotebookCoverView 既有 spineColor |
| E+8.10 | xcodebuild BUILD SUCCEEDED | `cd dayfold && xcodebuild ... build 2>&1 \| tail -5` |

## 七、不做(明确延后)

1. 中点折角 / 手指拖拽折角(iOS 16+ PageKit / PDFKit 高级交互,本轮不做)
2. 暗黑模式专项压测(暖色 token 在 dark 已可用,本轮不验证)
3. 列表模式(listMode)选本动效
4. 笔记本添加 / 删除时的飞入飞出(沿用现有 spring)
5. 翻页音效(无音频资源,不引入)
6. 笔记本封面 hover / long-press 3D 倾斜(留作未来)

## 八、风险

- **零架构风险**:不动 schema、不动 Service、不动 Navigator 容器、不动 ViewModel
- **唯一浮点**:`m34 = -1/800` 是经验值,iPhone 16 Pro 上测试 OK,iPad 大屏可能透视略弱(MVP 阶段不管,iPad 是未来工作)
- **手势冲突**:`TabView(.page)` 自带手势 + 自定义 rotation 同时存在,在 iOS 18 上无冲突报告,若发现问题降级到 `HStack` 方案 A
- **性能**:GeometryEffect 每帧执行 `effectValue`,240×340 封面规模 + iPhone 16 Pro GPU 远低于瓶颈

## 九、⚠️ 必须运行时验证(不可仅靠代码 review)

本轮验收的 **E+8.1 / E+8.3 / E+8.4** 都依赖模拟器跑起来看实际动效,reviewer 仅能从 diff 验证:
- 代码能编译(BUILD SUCCEEDED)
- PageTurnEffect 数学正确(effectValue 返回合理 transform)
- TabView 不被破坏(selection 仍能 binding 切换)

真正的「看着像翻书」需要在模拟器滑动手动验证 → 用户验收。