# Timeline 日历模式 & 照片墙模式设计文档

**日期**: 2026-05-29  
**状态**: 已批准  
**涉及文件**: `TimelineView`, `TimelineViewModel`, `CalendarView`, `PhotoWallView`, `Entry` 模型

---

## 背景

`TimelineView` 已实现列表模式，日历模式和照片墙模式为占位符（`Text("... 待实现")`）。本文档描述这两个模式的完整设计，以及支撑它们所需的数据模型变更。

---

## 整体架构

三个模式共享 `TimelineViewModel` 中的状态，切换模式时保留上下文。

```
TimelineView
├── Picker（列表 / 日历 / 照片墙）
├── TimelineListView          ← 已实现，无需改动
├── CalendarView              ← 新增
│   ├── MonthGridView         月历网格
│   ├── DayCell               单日格子（含圆点指示）
│   └── EntryBottomSheet      可拖拽抽屉
└── PhotoWallView             ← 新增
    └── PhotoWallGrid         交错网格（大/小格混排）
```

### TimelineViewModel 新增属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `selectedDate` | `Date?` | 三模式共享的选中日期 |
| `currentMonth` | `Date` | 日历当前显示月份 |
| `entriesWithPhotos` | `[Entry]` | 照片墙专用（只取有 mediaAssets 的条目） |
| `favoriteEntriesWithPhotos` | `[Entry]` | 收藏且有图片的条目（用于大格） |

---

## 数据模型变更

### Entry 新增 isFavorite 字段

- **Core Data**：`Entry` 实体新增 `isFavorite: Bool`，默认 `false`
- **Entry.swift**：添加 `var wrappedIsFavorite: Bool` 计算属性
- **迁移策略**：轻量级迁移（Lightweight Migration），Core Data 自动处理，无需 mapping model

### 影响范围

- `EntryEditorView` / `EntryEditorViewModel`：添加收藏切换按钮（★）
- `EntryDetailView`：导航栏右上角显示收藏状态，可切换
- `TimelineViewModel`：新增 `favoriteEntriesWithPhotos` 查询

---

## 日历模式

### 月历网格（MonthGridView）

- 7列，动态行数（4-6行），按当月实际天数渲染
- **圆点指示器**（有记录的日期）：
  - 暖橙（`warmAccent`）= 含图片的条目
  - 暖棕（`warmBrown`）= 纯文字条目
  - 多条目并排最多 3 个点，超过显示 `3+` 数字
- 今天：填色圆背景高亮
- 选中日期：深色边框标记
- **月份切换**：顶部左右箭头按钮 + 横向 `DragGesture` 手势（左滑下月，右滑上月）

### 底部抽屉（EntryBottomSheet）

实现方式：`CalendarView` 底部用 `.overlay` + `VStack` 自绘抽屉，而非 `.sheet`，避免与外层 `NavigationView` 的 sheet 嵌套冲突。通过 `@GestureState` + `DragGesture` 控制抽屉高度，三档吸附：



| 档位 | 高度 | 内容 |
|---|---|---|
| 默认 | `~80pt` | 摘要条："5月7日 · 2条记录" + `+` 按钮 |
| 中档 | `.medium` | 紧凑条目卡片列表（可滚动） |
| 全屏 | `.large` | 完整条目列表，支持跳转详情 |

**空日期（无记录）**：摘要条显示"这天还没有记录" + `+` 按钮，点击 → 新建条目 Sheet，预填 `createdAt` 为选中日期。

**有记录日期**：摘要条右侧同样有 `+` 按钮，快捷添加当天新记录。

### 与照片墙联动

抽屉内条目卡片有图片时，点击图片区域 → 切换到照片墙模式，滚动到该条目位置。

---

## 照片墙模式

### 交错网格（PhotoWallGrid）

**布局规则**：
- 基础单位：3列等宽网格
- **收藏（★）条目**的第一张图占 **2×2 大格**（跨2列2行），大格始终放在当前行的左侧（列0-1），右侧空余1列填入小格
- 连续两个收藏条目时，第二个降级为小格（避免布局混乱），下一行再恢复大格
- 其余条目占 **1×1 小格**
- 按 `createdAt` 倒序混排，使用 `LazyVGrid` + 自定义 `GridItem` 实现

**单格显示**：
- 小格：正方形缩略图，图片数 ≥ 2 时右上角显示角标（`🖼 3`）
- 大格：同上，右上角额外显示 `★` 收藏标记
- 点击任意格 → 跳转 `EntryDetailView`

### 快捷编辑

长按图片格 → 上下文菜单（`contextMenu`）：
- "编辑条目" → 跳转 `EntryEditorView`
- "取消收藏" / "加入收藏" → 切换 `isFavorite`，大小格即时刷新

### 空状态

无带图片条目时，显示居中插图 + 文案："还没有带图片的记录，拍张照片开始吧"

### 与日历联动

从日历抽屉点击图片跳转到此处时，滚动到对应条目位置并短暂高亮（0.3s 缩放动画）。

---

## 交互流程图

```
列表模式
  └─ 无改动

日历模式
  ├─ 左右滑动 / 箭头 → 切换月份
  ├─ 点击有记录日期 → 抽屉升至 medium，展示条目
  │   ├─ 点击条目图片 → 切换到照片墙，定位到该条目
  │   └─ 点击 + → 新建条目（预填日期）
  └─ 点击空白日期 → 抽屉显示"无记录" + +

照片墙模式
  ├─ 点击图片格 → 条目详情
  └─ 长按图片格 → 上下文菜单（编辑 / 收藏切换）
```

---

## 不在本次范围内

- 照片墙中的全屏图片浏览（预留给后续迭代）
- 日历的年视图
- 基于位置/天气的日历过滤

---

## 实现顺序建议

1. `Entry.isFavorite` 数据模型变更 + 轻量级迁移
2. `TimelineViewModel` 新增属性和查询方法
3. `CalendarView`（MonthGridView + DayCell + EntryBottomSheet）
4. `PhotoWallView`（PhotoWallGrid + 大小格布局）
5. 联动逻辑（selectedDate 共享 + 跳转滚动）
6. `EntryDetailView` / `EntryEditorView` 收藏按钮
