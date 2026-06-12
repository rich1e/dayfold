# Dayfold UI 改版设计规格 — 导航重构 & 动效系统

**日期**：2026-06-12  
**范围**：导航结构重构 + 全局动效系统  
**参考**：Hardcover 私密相册（精致感、层次感、物理动效）

---

## 背景

当前 Dayfold 使用系统默认 `TabView`，底部 Tab Bar 平铺三项，整体交互感生硬，缺少与"温暖纸质感"主题匹配的动效与空间层次。本次改版聚焦两个方向：

1. **导航重构**：底部 Tab Bar → 侧边图标导航栏
2. **动效系统**：建立全局"纸张翻页"动效基调

---

## 一、侧边导航栏

### 布局

- 整体结构：`HStack { SidebarView + 内容区 }`，替代原 `TabView`
- 侧边栏宽度：**48pt**
- 背景色：`Color.warmLight (#F9F7F1)`
- 右侧分割线：1pt，`Color.warmCream`

### 导航项

| 项目 | 图标 | 标签 |
|------|------|------|
| 时间轴 | `clock` | 时间轴 |
| 全部日记 | `book.closed` | 全部 |
| 标签管理 | `tag` | 标签 |

每项尺寸：36×36pt，`cornerRadius(10)`

### 激活态

- 背景：`Color.warmAccent.opacity(0.13)` 圆角背景块
- 图标 + 标签文字：`Color.warmAccent`
- 未激活：图标默认色，标签 `Color.warmBrown.opacity(0.6)`
- 切换动效：`matchedGeometryEffect(id: "activeTab", in: sidebarNamespace)`，spring 曲线 `response: 0.3, dampingFraction: 0.8`

### 新建按钮（FAB）

- 位置：侧边栏底部，距底部 16pt
- 尺寸：44×44pt 圆形
- 颜色：`Color.warmAccent`，白色 `plus` 图标
- 阴影：`Color.warmAccent.opacity(0.35)`，radius 8，y 3
- 点击动效：scale 0.9 → 1.0，spring(response: 0.3, dampingFraction: 0.6)
- 功能：弹出 `EntryEditorView` sheet（与原 toolbar 按钮相同）

---

## 二、动效系统

### 核心 Transition：paperDrop

定义在 `Extensions/Transitions+Warm.swift`：

```swift
// 进入：从略微倾斜+偏移状态落平
// 离开：淡出
extension AnyTransition {
    static var paperDrop: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: PaperDropModifier(progress: 0),
                identity: PaperDropModifier(progress: 1)
            ),
            removal: .opacity
        )
    }
}

struct PaperDropModifier: ViewModifier {
    let progress: Double  // 0 = 起始，1 = 落定
    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .rotation3DEffect(.degrees(-8 * (1 - progress)), axis: (1, 0, 0))
            .offset(y: 12 * (1 - progress))
    }
}
```

动效时长：**0.38s**，曲线：`easeOut`

### Tab 切换

- 内容区包裹 `ZStack`，用 `if selectedTab == .xxx` 切换
- 每次切换新内容用 `.transition(.paperDrop)`
- 整体用 `withAnimation(.easeOut(duration: 0.38))` 驱动

### 卡片列表入场

适用视图：`EntryListView`、`TimelineListView`

```swift
ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
    EntryCard(entry: entry, ...)
        .transition(.paperDrop)
        .animation(
            .easeOut(duration: 0.38).delay(Double(index) * 0.07),
            value: entriesLoaded   // Bool，数据加载完成后触发
        )
}
```

入场延迟：每张卡片 **70ms** 间隔，最多计算前 8 张（之后无延迟，避免等待过长）

### 卡片点击反馈

所有 `EntryCard` 添加 press 反馈：

```swift
.scaleEffect(isPressed ? 0.97 : 1.0)
.animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
```

通过 `DragGesture(minimumDistance: 0)` 或 `.buttonStyle` 检测按下状态。

### NavigationLink 页面推入

保留系统默认右滑动效，叠加内容区轻微 opacity 淡出（0.15s）以增加层次感，不自定义完整转场（避免与系统手势冲突）。

---

## 三、改动文件清单

### 新增

| 文件 | 内容 |
|------|------|
| `Views/SidebarView.swift` | 侧边导航栏组件，含 FAB |
| `Extensions/Transitions+Warm.swift` | `paperDrop` transition + `PaperDropModifier` |

### 修改

| 文件 | 改动摘要 |
|------|----------|
| `Views/MainTabView.swift` | `TabView` 替换为 `HStack { SidebarView + contentView }` |
| `Views/Entry/EntryListView.swift` | 移除 toolbar 新建按钮；卡片列表加入场动效；卡片加点击反馈 |
| `Views/Timeline/TimelineView.swift` | 移除 toolbar（若有）新建按钮；页面切换接入 paperDrop |
| `Views/Tags/TagsView.swift` | 动效接入 |

### 不改动

- `EntryDetailView`、`EntryEditorView`、`CalendarView`、`PhotoWallView` 内部结构
- Core Data 层、颜色系统、字体系统
- `LockScreenView`

---

## 四、验收标准

1. 侧边栏激活背景块在三个 Tab 间切换时平滑滑动（matchedGeometryEffect 无跳变）
2. Tab 内容切换时有纸张翻页效果（rotateX + 位移 + 淡入）
3. 日记列表卡片首次加载时错落入场，无卡顿
4. 卡片点击有轻微压缩反馈
5. FAB 点击弹出新建编辑器，与原功能一致
6. 横竖屏、深色模式下布局无异常
7. xcodebuild BUILD SUCCEEDED，无新增 error

---

## 五、不在此次范围

- 列表卡片视觉升级（封面大图、排版调整）
- 编辑器沉浸感改造
- 详情页阅读体验
- 深色模式专项适配
