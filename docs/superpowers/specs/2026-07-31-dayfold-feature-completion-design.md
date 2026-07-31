# Dayfold 功能补全 · 设计文档

> 生成日期：2026-07-31
> 背景：UI 设计稿（Stitch `re-dayfold`，15 定稿页 + 设计系统）已基本完成。本轮把代码侧 7 项已知功能缺口排成完整开发计划并落地。
> 依据：源码实测核实（截至最新提交 `28d2f1a feat: 新增地图页面`）。

## 一、目标与范围

把以下 7 项已核实的功能缺口全部补齐，按「依赖关系 + 影响面」分阶段交付。每阶段结束须 `xcodebuild` BUILD SUCCEEDED。

| # | 缺口 | 现状 | 阶段 |
|---|------|------|------|
| 1 | 笔记本持久化 | `Notebook` 仅为 HomeView 内 struct + @State，无 Core Data 实体；NotebookDetailView 拉全部日记不隔离 | A |
| 2 | Markdown / FormattingToolbar 接入编辑器 | 组件已写好，仅 Preview 引用，编辑器用原生 TextEditor | B1 |
| 3 | TagPicker 挂载编辑器 | 数据层就绪（VM 有 selectedTags），UI 未挂载 | B2 |
| 4 | 编辑器取消按钮 + 保存失败提示 | 只有「完成」，无取消；showingSaveError 无触发路径 | B3 |
| 5 | mood 心情输入 | schema 有字段，无任何 UI/save 写入 | B4 |
| 6 | TagsView 导航入口 + 新建按钮 | SidebarTab 无 tags；TagsView 无「+」；全局无引用 | C1 |
| 7 | EntryListView 筛选 UI | VM 有 showFavoritesOnly/selectedTags 逻辑，无 UI | C2 |
| 8 | TimelineView 路径 PhotoWall 点击 | NotebookDetail 已修；TimelineView 未传 onSelectEntry；contextMenu「编辑条目」空闭包 | C3 |
| 9 | 数据统计页 / 设置页 | 落 PlaceholderView | D1 / D2 |

（编号 1–9 覆盖原 7 项缺口，其中原第 7 项拆为编辑器取消/mood/占位页多条。）

## 二、关键决策（已与用户确认）

1. **存量数据不迁移** —— 现有日记均为测试数据，无需回填 notebook 关系；但保留「默认笔记本兜底」防空状态。
2. **CloudKit 兼容** —— 笔记本实体建模严守 `NSPersistentCloudKitContainer` 约束：所有关系可选、必有反向关系。
3. **删笔记本 = 软删除该本下日记** —— 本下未删日记逐个 `moveToTrash()`（进回收站），再删本实体；不物理级联删除。
4. **回收站恢复 = 用户选目标笔记本** —— 恢复时弹「笔记本选择器」，用户指定恢复到哪个本。
5. **编辑器「取消」= 真正放弃（方案 b）** —— 新建物理删除草稿；编辑既有日记按快照完整回滚（含图片）。
6. **缺稿开工前一次性补齐** —— 用 Stitch 生成本轮所有缺失/待细化设计稿，经用户确认后再编码。
7. **D 阶段全实现** —— 统计页做完整维度，设置页做完整项。

## 三、分阶段计划

```
阶段 0 · 补齐缺稿（Stitch 生成 → 用户确认）   ← 开工前完成
阶段 A · 笔记本持久化                          ← 唯一动 schema，最先
阶段 B · 编辑器接线（B1~B4）                   ← 写日记体验
阶段 C · 检索与导航补全（C1~C3）               ← 导航/筛选接线
阶段 D · 占位页落地（D1 统计 / D2 设置）        ← 新功能
```

排序逻辑：A 唯一改 schema 且是数据正确性缺口，最先做迁移成本最低；B/C 无强依赖，B 优先（直接影响写日记）；D 为纯新功能放最后。

---

### 阶段 0 · 补齐缺稿（Stitch）

复用现有设计系统 asset `4b1bee32e3894e98a837dda03816a473`（项目 `re-dayfold`，ID `13633875149271731736`）。

需生成的稿：

| 稿 | 用途 | 服务阶段 |
|----|------|---------|
| 心情选择控件 | 编辑器内选心情 | B4 |
| 编辑器标签选择态 | TagPicker 挂载位置 | B2 |
| 列表筛选态 | 收藏/标签筛选 UI 形式 | C2 |
| 笔记本选择器 Sheet | 回收站恢复选本（可复用于新建/移动日记） | A |
| 数据统计页 | .stats 落地 | D1 |
| 设置页 | .settings 落地 | D2 |

产物落盘到 `docs/stitch-assets/`，更新 `labeled-screens.json`，逐一交用户确认后进入编码。

---

### 阶段 A · 笔记本持久化

**数据模型（CloudKit 兼容）**

新增 `Notebook` 实体：

| 属性 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| name | String | 笔记本名 |
| coverStyle | String | CoverStyle 枚举 rawValue |
| createdAt | Date | 创建时间 |
| sortOrder | Int32 | 排序 |

关系：`Notebook.entries ⟷ Entry.notebook`（一对多）
- **两端可选**（CloudKit 硬约束）
- `Notebook → entries` 删除规则 `Nullify`（删本不物理删日记；日记的物理去留由软删除逻辑负责）

**代码改造**

1. `Models/Notebook.swift`：NSManagedObject 扩展 + `create()` 工厂 + `CoverStyle` 枚举（从 HomeView 迁出）。
2. `Services/CoreDataStack.swift`：首启若无笔记本则种一个「默认笔记本」（参照现有 `createPresetTags()`）。
3. `Views/HomeView.swift`：`@State notebooks: [Notebook]` → `@FetchRequest<Notebook>`；增删改走 Core Data。
4. `Views/NotebookDetailView.swift`：`@FetchRequest` 谓词加 `notebook == %@`（连同 `deletedAt == nil`）→ 真正隔离数据。
5. `ViewModels/EntryEditorViewModel.swift`：`init` 增 `notebook` 参数，`save()` 写入 `entry.notebook`。

**删笔记本逻辑**（`HomeView.deleteCurrentNotebook()` 或 `Notebook` 扩展方法）

```
删除笔记本 N：
  1. 遍历 N.entries 中 deletedAt == nil 的日记 → 逐个 entry.moveToTrash()
  2. 删除 Notebook 实体（entries 关系因 Nullify 自动解绑）
  3. context.save()
效果：这些日记从所有笔记本视图消失，出现在回收站；可恢复。
```

**回收站恢复逻辑**（`Views/Entry/TrashView.swift`）

```
点「恢复」：
  1. 弹「笔记本选择器」Sheet（阶段 0 设计稿），列出所有现存 Notebook
  2. 用户选定 → entry.restore()（deletedAt = nil）+ entry.notebook = 选中本
  3. context.save() → 日记回到该本
边界：
  · 无任何笔记本时 → 选择器提供「新建笔记本」入口，或先建默认本
  · 「全部恢复」（若保留）→ 批量指定同一目标本
```

**不做**：存量数据迁移。**保留**：默认笔记本兜底防空状态崩溃。

---

### 阶段 B · 编辑器接线

**B1 · Markdown 编辑器接入**
- `EntryEditorView.swift:136` 原生 `TextEditor(text: $viewModel.content)` → `MarkdownEditor(text: $viewModel.content)`。
- `MarkdownEditor` 内部已挂 `FormattingToolbar`（加粗/斜体/列表/有序列表/引用/链接/待办 7 键），挂上即生效。
- 移除 `keyboardToolbar` 中空闭包的 `textformat` 按钮（`:212`），避免与 MarkdownEditor 自带工具栏重复。
- 验证：各格式按钮能正确插入 Markdown 标记。

**B2 · TagPicker 挂载**
- 编辑器加入 `TagPicker`，绑定 `viewModel.selectedTags`（VM 层 selectedTags / addTag / removeTag / save 写回均已就绪）。
- 摆放位置依阶段 0「编辑器标签选择态」稿确定。

**B3 · 取消按钮 + 保存失败提示 + 取消回滚（方案 b）**

取消语义分场景：

```
【新建日记】(entry 进入前为 nil)
  · 已 auto-save 创建 Entry → 物理删除 Entry + 其 MediaAsset 磁盘文件 + Location
    （复用 EntryListViewModel 的级联清理媒体逻辑）；不进回收站。
  · 未 auto-save → 直接 dismiss。

【编辑既有日记】(entry 进入时已存在)
  · 进入时对原始字段拍快照 EntrySnapshot：
    title / content / mood / selectedTags / 图片 filename 列表 / isFavorite / location
  · 取消 → 按快照回滚全部字段 → save() 写回原值 → dismiss。
```

**图片完整回滚（B3 子项，本阶段技术重点）**
- 现状 auto-save 增删图片走全量重建，`deleteImage` 立即物理删旧图 → 取消时原图找不回。
- 改为**延迟删除**：编辑期间不物理删旧图文件，仅在「完成」保存成功后才清理被移除的旧图；取消时旧图文件仍在，按快照重建 MediaAsset 即可恢复。
- 实现要点：`EntryEditorViewModel` 加 `private var originalSnapshot: EntrySnapshot?`（编辑既有日记时填充）+ `cancel()` 方法封装上述分支。
- **须重点测试**：编辑既有日记 → 增删图片 → 取消 → 图片恢复到原始状态。

**保存失败提示**
- `topBar` 左侧加「取消」按钮。
- 接通 `showingSaveError`：`save()` 中被 `try?` 吞掉的错误改为捕获 → 置 `showingSaveError = true` → `.alert`。
- 保留现有「title 与 content 双空跳过保存」守卫。

**B4 · 心情输入**
- `Entry.mood` 已在 schema。VM 加 `@Published var mood: String`，`save()` 写入。
- 编辑器加心情选择控件（形式依阶段 0 稿）。

---

### 阶段 C · 检索与导航补全

**C1 · TagsView 导航入口 + 新建按钮**
- `Views/SidebarView.swift`：`SidebarTab` 加 `case tags`，归入 group1（日记组）。
- `Views/MainTabView.swift`：`selectedTab` 分支加 `.tags → TagsView`。
- `Views/Tags/TagsView.swift`：toolbar `EditButton()` 旁加「+」→ 弹 `TagEditorView`（新建态）→ `TagManagerViewModel.createTag`。
- 复用现有标签管理页 + 编辑页，无缺稿。

**C2 · EntryListView 筛选 UI**
- `.searchable` 之外加筛选控件：收藏开关 + 标签多选，绑定 `EntryListViewModel.showFavoritesOnly` / `selectedTags`（逻辑已就绪）。
- 摆放形式依阶段 0「列表筛选态」稿。

**C3 · TimelineView 路径 PhotoWall 点击**
- `Views/Timeline/TimelineView.swift:37`：调 `PhotoWallView` 补传 `onSelectEntry`（参照 NotebookDetailView:185）。
- `Views/Timeline/PhotoWallView.swift:181-184`：contextMenu「编辑条目」空闭包 → 接 `onEditEntry` 回调，由调用方处理跳转。
- 纯接线，无缺稿。

---

### 阶段 D · 占位页落地

**D1 · 数据统计页（.stats）**
- 新建 `Views/StatsView.swift` + `StatsViewModel`。
- 统计维度（完整）：总日记数、本月数、今年数、连续记录天数（streak）、标签分布、带图比例、带位置比例。
- `Views/MainTabView.swift`：`.stats` 分支 PlaceholderView → StatsView。
- 展现形式依阶段 0 稿。

**D2 · 设置页（.settings）**
- 新建 `Views/SettingsView.swift`。
- 设置项（完整）：Face ID 锁屏开关（接 `SecurityManager.isEnabled`）、默认笔记本选择、iCloud 同步状态显示、关于/版本号。
- `Views/MainTabView.swift`：`.settings` 分支 → SettingsView。
- 展现形式依阶段 0 稿。

## 四、涉及文件汇总

**新增**
- `Models/Notebook.swift`
- `Views/StatsView.swift`、`ViewModels/StatsViewModel.swift`
- `Views/SettingsView.swift`
- 笔记本选择器组件（复用于恢复/新建/移动，如 `Views/Common/NotebookPickerSheet.swift`）
- `dayfold.xcdatamodeld` 新增 Notebook 实体 + Entry.notebook 关系（新模型版本）

**改造**
- `Services/CoreDataStack.swift`（默认笔记本种子）
- `Views/HomeView.swift`（@FetchRequest<Notebook>、CoverStyle 迁出、删本逻辑）
- `Views/NotebookDetailView.swift`（谓词加 notebook）
- `Views/Entry/EntryEditorView.swift`（MarkdownEditor、TagPicker、取消按钮、mood、错误提示）
- `ViewModels/EntryEditorViewModel.swift`（notebook 参数、mood、快照/cancel、延迟删图、错误捕获）
- `Views/Entry/TrashView.swift`（恢复选本）
- `Views/SidebarView.swift`、`Views/MainTabView.swift`（tags 入口、stats/settings 分支）
- `Views/Tags/TagsView.swift`（新建按钮）
- `Views/Entry/EntryListView.swift`（筛选 UI）
- `Views/Timeline/TimelineView.swift`、`Views/Timeline/PhotoWallView.swift`（onSelectEntry / onEditEntry）

## 五、验收标准

- 每阶段结束 `xcodebuild ... build` BUILD SUCCEEDED。
- **A**：重启后笔记本保留；不同笔记本只显示各自日记；删本后其日记进回收站；恢复时可选目标本。
- **B**：编辑器可用 Markdown 格式化、写日记时选标签、选心情；取消能真正放弃（新建抹除、编辑完整回滚含图片）；保存失败有提示。
- **C**：侧边栏可进标签页并新建标签；列表可按收藏/标签筛选；TimelineView 照片墙点击可进详情、长按可编辑。
- **D**：统计页展示全部维度；设置页各项可用（Face ID 开关生效、默认本可选、版本号正确）。

## 六、风险与注意

- **CloudKit schema 变更**：新增 Notebook 实体需新建模型版本（轻量迁移）；关系务必全可选 + 双向。
- **图片延迟删除**：改动 auto-save 的媒体清理时机，须回归测试「正常保存后旧图确实被清理」与「取消后旧图恢复」两条路径。
- **默认笔记本兜底**：任何删本/恢复/首启路径都不能出现「零笔记本」导致的空状态崩溃。
- **既有交互约定**（见 PROJECT_OVERVIEW.md 第四节）：sheet/fullScreenCover 内须再次注入 managedObjectContext；行内属性变化视图用 @ObservedObject。
