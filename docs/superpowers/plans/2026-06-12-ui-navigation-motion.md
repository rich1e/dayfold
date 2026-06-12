# UI 导航重构 & 动效系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将底部 TabView 替换为侧边图标导航栏，并建立"纸张翻页"动效基调，提升 Dayfold 的视觉层次与交互质感。

**Architecture:** 新增 `SidebarView` 组件和 `Transitions+Warm` 扩展，`MainTabView` 改为 `HStack { SidebarView + ZStack 内容区 }` 结构，通过 `@State selectedTab` 枚举驱动内容切换，`paperDrop` transition 应用于 Tab 切换与卡片列表入场。

**Tech Stack:** SwiftUI（iOS 18.1），`matchedGeometryEffect`，`rotation3DEffect`，`AnyTransition`，`ViewModifier`

---

## 文件结构

| 操作 | 路径 | 职责 |
|------|------|------|
| 新增 | `dayfold/Extensions/Transitions+Warm.swift` | `PaperDropModifier` + `AnyTransition.paperDrop` |
| 新增 | `dayfold/Views/SidebarView.swift` | 侧边导航栏 + FAB |
| 修改 | `dayfold/Views/MainTabView.swift` | TabView → HStack 布局，持有 selectedTab 状态 |
| 修改 | `dayfold/Views/Entry/EntryListView.swift` | 移除 toolbar 新建按钮；卡片入场动效；press 反馈 |
| 修改 | `dayfold/Views/Timeline/TimelineView.swift` | Tab 内容切换接入 paperDrop |
| 修改 | `dayfold/Views/Timeline/TimelineListView.swift` | 卡片入场动效；press 反馈 |

---

## Task 1: 创建 paperDrop Transition

**Files:**
- Create: `dayfold/dayfold/Extensions/Transitions+Warm.swift`

- [ ] **Step 1: 创建文件，写入完整实现**

```swift
// Extensions/Transitions+Warm.swift
import SwiftUI

struct PaperDropModifier: ViewModifier {
    let progress: Double // 0 = 起始（倾斜+偏移），1 = 落定

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .rotation3DEffect(
                .degrees(-8 * (1 - progress)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
            .offset(y: 12 * (1 - progress))
    }
}

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
```

- [ ] **Step 2: 构建验证**

```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -3
```

期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add dayfold/dayfold/Extensions/Transitions+Warm.swift
git commit -m "feat: 添加 paperDrop Transition 和 PaperDropModifier"
```

---

## Task 2: 创建 SidebarView 组件

**Files:**
- Create: `dayfold/dayfold/Views/SidebarView.swift`

- [ ] **Step 1: 创建文件，写入完整实现**

```swift
// Views/SidebarView.swift
import SwiftUI
import CoreData

enum SidebarTab: CaseIterable {
    case timeline, list, tags

    var icon: String {
        switch self {
        case .timeline: return "clock"
        case .list:     return "book.closed"
        case .tags:     return "tag"
        }
    }

    var label: String {
        switch self {
        case .timeline: return "时间轴"
        case .list:     return "全部"
        case .tags:     return "标签"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    var onNewEntry: () -> Void

    @Namespace private var sidebarNamespace
    @State private var fabPressed = false

    var body: some View {
        VStack(spacing: 0) {
            // 导航项
            VStack(spacing: 4) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    SidebarItem(
                        tab: tab,
                        isActive: selectedTab == tab,
                        namespace: sidebarNamespace
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.top, 16)

            Spacer()

            // FAB 新建按钮
            Button {
                onNewEntry()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.warmAccent)
                    .clipShape(Circle())
                    .shadow(
                        color: Color.warmAccent.opacity(0.35),
                        radius: 8, x: 0, y: 3
                    )
                    .scaleEffect(fabPressed ? 0.9 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !fabPressed {
                            fabPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            fabPressed = false
                        }
                    }
            )
            .padding(.bottom, 24)
        }
        .frame(width: 48)
        .background(Color.warmLight)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.warmCream)
                .frame(width: 1)
        }
    }
}

private struct SidebarItem: View {
    let tab: SidebarTab
    let isActive: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.warmAccent.opacity(0.13))
                        .frame(width: 36, height: 36)
                        .matchedGeometryEffect(id: "activeTab", in: namespace)
                }

                VStack(spacing: 3) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .warmAccent : .warmBrown.opacity(0.6))

                    Text(tab.label)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(isActive ? .warmAccent : .warmBrown.opacity(0.6))
                }
                .frame(width: 36, height: 36)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HStack {
        SidebarView(selectedTab: .constant(.timeline), onNewEntry: {})
        Spacer()
    }
    .background(Color.warmPaper)
}
```

- [ ] **Step 2: 构建验证**

```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -3
```

期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add dayfold/dayfold/Views/SidebarView.swift
git commit -m "feat: 新增 SidebarView 侧边导航栏组件"
```

---

## Task 3: 重构 MainTabView

**Files:**
- Modify: `dayfold/dayfold/Views/MainTabView.swift`

- [ ] **Step 1: 用完整内容替换 MainTabView**

将 `dayfold/dayfold/Views/MainTabView.swift` 全部内容替换为：

```swift
// Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: SidebarTab = .timeline
    @State private var showingNewEntry = false

    var body: some View {
        HStack(spacing: 0) {
            // 侧边导航栏
            SidebarView(selectedTab: $selectedTab) {
                showingNewEntry = true
            }

            // 内容区域
            ZStack {
                Color.warmPaper.ignoresSafeArea()

                if selectedTab == .timeline {
                    TimelineView(context: viewContext)
                        .transition(.paperDrop)
                }
                if selectedTab == .list {
                    EntryListView(context: viewContext)
                        .transition(.paperDrop)
                }
                if selectedTab == .tags {
                    TagsView(context: viewContext)
                        .transition(.paperDrop)
                }
            }
            .animation(.easeOut(duration: 0.38), value: selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showingNewEntry) {
            EntryEditorView(context: viewContext)
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
```

- [ ] **Step 2: 构建验证**

```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -3
```

期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add dayfold/dayfold/Views/MainTabView.swift
git commit -m "feat: MainTabView 替换为侧边导航栏布局"
```

---

## Task 4: EntryListView — 移除 toolbar 按钮 + 卡片动效

**Files:**
- Modify: `dayfold/dayfold/Views/Entry/EntryListView.swift`

- [ ] **Step 1: 修改 EntryListView — 移除新建按钮，添加入场动效**

找到 `EntryListView` 的 `body`，做以下两处修改：

**1) 移除 toolbar 中的新建按钮**（整个 `.toolbar { }` 块删除）

**2) 在 `ScrollView` 内的 `LazyVStack` 中为卡片添加入场动效**，将：

```swift
LazyVStack(spacing: 16) {
    ForEach(filteredEntries, id: \.id) { entry in
        NavigationLink(destination: EntryDetailView(entry: entry)) {
            EntryCard(entry: entry, viewModel: viewModel)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
.padding()
```

替换为：

```swift
LazyVStack(spacing: 16) {
    ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
        NavigationLink(destination: EntryDetailView(entry: entry)) {
            EntryCard(entry: entry, viewModel: viewModel)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .transition(.paperDrop)
        .animation(
            .easeOut(duration: 0.38).delay(Double(min(index, 7)) * 0.07),
            value: filteredEntries.count
        )
    }
}
.padding()
```

**3) 同时删除 `showingNewEntry` 的 State 声明和对应 sheet**（FAB 已在 SidebarView 处理）：

删除：
```swift
@State private var showingNewEntry = false
```

删除：
```swift
.sheet(isPresented: $showingNewEntry) {
    EntryEditorView(context: viewContext)
}
```

删除 `emptyState` 中的新建按钮 `Button { showingNewEntry = true }` 块（保留文字描述部分）。

- [ ] **Step 2: 构建验证**

```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -3
```

期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add dayfold/dayfold/Views/Entry/EntryListView.swift
git commit -m "feat: EntryListView 移除 toolbar 新建按钮，添加卡片入场动效"
```

---

## Task 5: EntryCard — 添加 press 点击反馈

**Files:**
- Modify: `dayfold/dayfold/Views/Entry/EntryListView.swift`（`EntryCard` struct）

- [ ] **Step 1: 在 EntryCard 添加 press 状态和 scaleEffect**

在 `EntryCard` struct 顶部添加状态变量：

```swift
@State private var isPressed = false
```

在 `EntryCard` 的 `.warmCard()` modifier 后面添加：

```swift
.scaleEffect(isPressed ? 0.97 : 1.0)
.animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
```

在 `.contextMenu { }` 后面添加 gesture：

```swift
.simultaneousGesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in
            if !isPressed { isPressed = true }
        }
        .onEnded { _ in
            isPressed = false
        }
)
```

- [ ] **Step 2: 构建验证**

```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -3
```

期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add dayfold/dayfold/Views/Entry/EntryListView.swift
git commit -m "feat: EntryCard 添加 press 点击缩放反馈"
```

---

## Task 6: TimelineListView — 卡片入场动效 + press 反馈

**Files:**
- Modify: `dayfold/dayfold/Views/Timeline/TimelineListView.swift`

- [ ] **Step 1: TimelineEntryCard 添加 press 状态**

在 `TimelineEntryCard` struct 顶部添加：

```swift
@State private var isPressed = false
```

在 `TimelineEntryCard` 的根视图（`HStack`）后面追加：

```swift
.scaleEffect(isPressed ? 0.97 : 1.0)
.animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
.simultaneousGesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in
            if !isPressed { isPressed = true }
        }
        .onEnded { _ in
            isPressed = false
        }
)
```

- [ ] **Step 2: TimelineListView 卡片入场动效**

在 `TimelineListView` 的 `ForEach(dayEntries, id: \.id)` 中，将：

```swift
ForEach(dayEntries, id: \.id) { entry in
    NavigationLink(destination: EntryDetailView(entry: entry)) {
        TimelineEntryCard(entry: entry)
    }
    .buttonStyle(PlainButtonStyle())
    .padding(.horizontal)
    .padding(.vertical, 8)
}
```

替换为（需要同时在外层 `ForEach(groupedEntries)` 枚举 offset 计算全局 index）：

```swift
ForEach(Array(dayEntries.enumerated()), id: \.element.id) { localIdx, entry in
    NavigationLink(destination: EntryDetailView(entry: entry)) {
        TimelineEntryCard(entry: entry)
    }
    .buttonStyle(PlainButtonStyle())
    .padding(.horizontal)
    .padding(.vertical, 8)
    .transition(.paperDrop)
    .animation(
        .easeOut(duration: 0.38).delay(Double(min(localIdx, 7)) * 0.07),
        value: entries.count
    )
}
```

- [ ] **Step 3: 构建验证**

```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -3
```

期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add dayfold/dayfold/Views/Timeline/TimelineListView.swift
git commit -m "feat: TimelineListView 卡片入场动效与 press 反馈"
```

---

## Task 7: TimelineView 内部切换接入 paperDrop

**Files:**
- Modify: `dayfold/dayfold/Views/Timeline/TimelineView.swift`

- [ ] **Step 1: Group 内容切换添加动效**

将 `TimelineView` 中的 `Group { switch ... }` 块替换为：

```swift
ZStack {
    if viewModel.viewMode == .list {
        TimelineListView()
            .transition(.paperDrop)
    }
    if viewModel.viewMode == .calendar {
        CalendarView(viewModel: viewModel)
            .transition(.paperDrop)
    }
    if viewModel.viewMode == .photoWall {
        PhotoWallView(viewModel: viewModel, scrollTarget: photoWallScrollTarget)
            .transition(.paperDrop)
    }
}
.animation(.easeOut(duration: 0.38), value: viewModel.viewMode)
```

- [ ] **Step 2: 构建验证**

```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -3
```

期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add dayfold/dayfold/Views/Timeline/TimelineView.swift
git commit -m "feat: TimelineView 子视图切换接入 paperDrop 动效"
```

---

## Task 8: TagsView 动效接入

**Files:**
- Modify: `dayfold/dayfold/Views/Tags/TagsView.swift`

- [ ] **Step 1: 移除 toolbar 新建按钮**

删除 `TagsView` body 中的整个 `.toolbar { ToolbarItem ... }` 块。

同时删除 `@State private var showingNewTag = false` 和对应的 `.sheet(isPresented: $showingNewTag)` 块。

> **注意**：`editingTag` 的 sheet 保留（用于编辑已有标签）。

- [ ] **Step 2: TagRow 添加入场动效**

在 `TagsView` 的 `ForEach(tags, id: \.id)` 中，将：

```swift
ForEach(tags, id: \.id) { tag in
    TagRow(tag: tag)
        .onTapGesture {
            editingTag = tag
        }
}
```

替换为：

```swift
ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
    TagRow(tag: tag)
        .onTapGesture {
            editingTag = tag
        }
        .transition(.paperDrop)
        .animation(
            .easeOut(duration: 0.38).delay(Double(min(index, 7)) * 0.07),
            value: tags.count
        )
}
```

- [ ] **Step 3: 构建验证**

```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | tail -3
```

期望输出：`** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add dayfold/dayfold/Views/Tags/TagsView.swift
git commit -m "feat: TagsView 移除 toolbar 新建按钮，添加标签入场动效"
```

---

## Task 9: 端对端验证

- [ ] **Step 1: 全量构建**

```bash
cd dayfold && xcodebuild \
  -project dayfold.xcodeproj \
  -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
```

期望：只有 `** BUILD SUCCEEDED **`，无新增 `error:`

- [ ] **Step 2: 启动 App 验证**

```bash
bash scripts/dev.sh 2>&1 | tail -20
```

期望：App launched，No unknown Error / Fault / Warning found

- [ ] **Step 3: 手动验收清单**

在模拟器中逐项确认：

1. ☐ 侧边栏可见，宽 48pt，三个图标正常显示
2. ☐ 点击导航项，金色背景块平滑滑动到新项
3. ☐ Tab 内容切换有纸张翻页效果（轻微 rotateX + 位移 + 淡入）
4. ☐ 日记列表卡片错落入场（首次进入 Tab 时）
5. ☐ 卡片点击有轻微压缩反馈
6. ☐ 金色 FAB 点击弹出新建编辑器
7. ☐ FAB 按下时有轻微缩小反馈
8. ☐ 标签管理页标签列表入场动效正常

- [ ] **Step 4: 最终 Commit（如有遗漏文件）**

```bash
git status
# 确认无遗漏后，若有未提交文件：
git add -p
git commit -m "chore: 导航重构与动效系统收尾"
```
