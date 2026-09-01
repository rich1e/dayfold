# Dayfold HANDOFF — 阶段 F · 笔记本详情编辑路径修复(2026-09-01)

## 1. 当前任务目标与验收标准

**今日已闭合阶段(2026-09-01)**:

| 阶段 | 范围 | commit | 状态 |
|------|------|--------|------|
| F1 · 笔记本详情页 toolbar 隐藏 bug 修复 | `NotebookDetailView` 的 `entryDetail` sheet 缺 `NavigationStack`,导致 `EntryDetailView` 的 `.toolbar` (收藏/分享/**编辑**/导出) 整组不渲染 | `8b845ca` 之后未独立 commit,合并入 F2 同 commit | ✅ |
| F2 · 单击条目直接进编辑器 | `SheetMode` 新增 `.entryEditor(Entry)` 分支,时间轴条目 + 照片墙 `onSelectEntry` 全部跳 `EntryEditorView`,跳过详情页二跳 | `21ff12f` | ✅ |

**当前 main HEAD**:`21ff12f`(领先 origin/main,本地未推)

**阶段 F 验收**(已通过):
- ✅ `xcodebuild ... build` → `** BUILD SUCCEEDED **`
- ✅ 录屏复测:首页 → 笔记本 → 点条目 → 直接弹起 `EntryEditorView`(顶部日期 + 右上"⋯" + "完毕")→ 修改 → 完毕 → 返回列表,`@FetchRequest` 自动刷新

**承上阶段未受影响**:E++ 导出菜单 / 阶段 A-E 笔记本持久化 / 阶段 B 编辑器接线全部不受本次改动波及。

## 2. 已读/已改的文件路径(本阶段增量)

- 改:`dayfold/dayfold/Views/NotebookDetailView.swift`
  - `SheetMode` 枚举(行 5-14)新增 `.entryEditor(Entry)`,id = `"editor-\(objectID)"`
  - 行 144 时间轴条目 `onTapGesture` → `sheetMode = .entryEditor(row.entry)`
  - 行 187 照片墙 `onSelectEntry` → `sheetMode = .entryEditor(entry)`
  - 行 204-209 新增 `case .entryEditor(let entry):` → `EntryEditorView(entry:, context:)`
  - 行 208-210 `.entryDetail` 分支前一轮保留 `NavigationStack` 包裹 + `.environment(\.managedObjectContext, context)` —— 为未来长按/分享等走详情页的入口备路
- 未改:`EntryDetailView` / `EntryEditorView` / `PhotoWallView` / `TimelineEntryRow` —— 路径切换是 sheet 调度层的事,不动业务视图

## 3. 测试结果与构建状态

最后一次构建(本阶段):
```
cd dayfold && xcodebuild -project dayfold.xcodeproj -scheme dayfold \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
→ ** BUILD SUCCEEDED **
```

模拟器录屏验证:
- ✅ F1 修复前:笔记本→条目→详情页,右上角收藏/分享/**编辑**/⋯ 菜单全部缺失,看似"无法编辑"
- ✅ F1 + F2 修复后:笔记本→条目→**直接进入 `EntryEditorView`**(单跳),顶部日期 + 右上三件套(⋯ / 完毕)正常,保存后回到列表能立刻看到改动
- ✅ 回归:笔记本左下 `+` 新建 / 照片墙 / 日历 sheet(相册) 三条路径均未受影响
- ✅ 回归:`EntryListView` NavigationLink → 详情 → 编辑(两跳老路径)未改动,仍能用

## 4. 已做的决策及其理由

1. **F1 用 `NavigationStack` 包裹而非在 `NotebookDetailView` 顶部加 `NavigationView`**:`NotebookDetailView` 自身已被 `HomeView.fullScreenCover` 嵌套,顶部再加 `NavigationView` 会和 fullScreenCover 的退出手势冲突;最小破坏面是只在 `.entryDetail` 这个 sheet 子树里补 `NavigationStack`,让 toolbar 有可依附的 navigation bar。
2. **F2 走单跳,跳过详情页**:用户明确诉求"不要二次点击"。`EntryEditorView` 本身已完整支持"完毕 → save() → 关闭" + "⋯ / 删除 → 取消编辑" + "空内容守卫",不需要经过只读 detail 中转。
3. **`.entryDetail(Entry)` case 保留而非删除**:`EntryDetailView` 仍有"详情先于编辑"价值(未来长按/分享/菜单跳详情);既然不再主动触发,留着零成本,删了万一以后回滚要回写。
4. **不动 `EntryCard` / `EntryListView` / `TimelineListView` 的 NavigationLink 路径**:那些路径默认两跳(列表→详情→编辑),用户也习惯了。只有"笔记本内"这个特殊场景用户明确要单跳,其他路径保持现状。
5. **未拆 commit**:`8b845ca` 之后 F1 + F2 一次开发,但 F1 修复被 F2 单跳方案部分覆盖(sheet 入口改了),两者语义不可分,合成一个 commit。

## 5. 失败过的尝试及原因(避免重复踩坑)

1. **误判根因为"漏注 managedObjectContext"**:第一轮排查时盯 `.sheet` 没注入 context 这一项,核对源码发现其实已注入。**下次先按"页面表现缺失"倒推:详情页内容都能渲染 + 用户报的"不能编辑" → 第一怀疑应是 toolbar 不显示,而非数据写入链**。
2. **`NavigationView` 加顶部会被 `fullScreenCover` 退出手势吃掉**:**被 fullScreenCover 推入的子视图,顶部新增 NavigationView 容易冲突,优先用 `NavigationStack` 包需要 toolbar 的子树,而不要在父级加**。
3. **`SheetMode` 的 `id` 必须随新 case 更新**:switch 的 `id` 用 `objectID` 拼接同一类后缀(`detail-` vs `editor-`),否则 SwiftUI 切 case 时会因为 id 撞车复用同一 sheet 实例。

## 6. 待办(给后续接手者)

1. **`git push origin main`**(本阶段 21ff12f + 之前未推 commits)— **等用户明确指令再推**,详见 `~/.claude/projects/.../memory/feedback_no-auto-push.md`
2. **可选增强(待用户决定)**:
   - 进入单跳编辑器后,**长按**仍走 `EntryDetailView`(只读预览)?当前已具备该能力(预留 `.entryDetail` 分支),只差一个 `.onLongPressGesture` 添加
   - 照片墙里点击照片是否仍走单跳,还是回到"详情只读"模式?目前复用了 `entryEditor` 分支
3. **阶段 F 残余 Minor(0)**:无
4. **阶段 E++ 运行时验证**(未动,沿用上阶段 TODO):模拟器打开任意 Entry → Toolbar 三点 Menu → 导出 PDF/Markdown 走通
5. **阶段 E++ 残余 Minor(3 项,沿用上阶段 TODO)**:filenameSlug 重复 / 多余 `import PDFKit` / 非 ASCII 标题 slug 兼容
6. **阶段 D 残余 deferred minor(5 项,沿用上阶段 TODO)**:时区边缘 / GeometryReader / TagStat stale id / Info.plist 显式字段 / defaultNotebookName
7. **阶段 E 残余 Minor**:`warmPaper` token 统一
8. **后续候选**(沿用上阶段):E++2 视频附件 / E++5 私密条目 / E++4 深色模式 / E++6 年视图

---
(承上阶段 E++ 完成态备份保留于 git 历史 `eeecb00 / 56da4bb / ce9489c / 563e7e7 / 8b845ca`,详见先前 HANDOFF 描述)
