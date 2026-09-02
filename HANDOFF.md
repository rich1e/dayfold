---
updated: 2026-09-02T19:05:00+08:00
task: 阶段 H 图文混排 — 编辑器横向撑宽 bug 已修复并提交，阶段收尾
---

## 现状 (Where things stand)

**阶段 H（图文混排 Inline Rich Text）全部闭环**，上一版 HANDOFF 第 0 节记录的三个待验证现象已全部修复并经用户实测通过：

| 历史现象 | 状态 |
|---|---|
| A. 插入第 2 张图时整段被推出屏幕顶部 | 已修（1f07c0e 移除 ScrollViewReader scrollTo） |
| B. 插入第 1 张图时图片撑爆整屏 | 已修（本轮 f2fa507，真根因见下） |
| C. 重开编辑时界面内容被横向裁掉 | 已修（本轮 f2fa507，与 B 同根因） |

- 最新提交：`f2fa507 fix(editor): 锁死 UITextView 横向 intrinsic，修重开编辑界面被横向撑宽`
- **未 push**（按 no-auto-push 约定等明确指令）
- 工作区干净，`xcodebuild` BUILD SUCCEEDED，诊断日志已全部清除（`grep DF-WIDTH` 无残留）
- 已装到 booted iPhone 16 Pro 模拟器，用户实测三项均通过

**真根因（前 4 轮返工都没找对）**：非滚动 UITextView（`isScrollEnabled = false`）会把被超宽 attachment 撑大的 `contentSize.width` 报成 `intrinsicContentSize.width`，SwiftUI 父 VStack 采纳后整个界面被横向撑宽（实测 402 → 454.7pt），左侧日期/标题、右上「完毕」被推出屏幕两侧。前几轮都在改「喂给 attachment 的宽度」——那是上游，撑宽发生在下游的**尺寸汇报**环节。

## 下一步 (Next actions)

阶段 H 已收尾，无 pending 修复。可选项：

1. **push**：`git push origin main`（需用户明确指令）
2. **未完成的 wiki-capture**：用户执行了 `/wiki-capture`，但 wiki 配置解析全层级为空（无 `@name` override、CWD 向上无含 `OBSIDIAN_VAULT_PATH` 的 `.env`、`~/.config/obsidian-wiki` 与 `~/.obsidian-wiki` 均不存在）。磁盘上有两个真 vault 待用户选择：
   - `/Users/rich1e/workspace/experience`（有 index/hot/log.md + _raw/）
   - `/Users/rich1e/workspace/code/notes`（有 index/hot/log.md + _raw/）
   - 另两个含 `.obsidian` 的是纯代码仓（za-dplatform-flow-v2-core / feat-policyDetail），不是 vault
3. 阶段 H 手工验证清单（旧 HANDOFF 第 4 节）中「Markdown 导出」「Backspace 删图」两项本轮未复测

## 卡点与约束 (Blockers & constraints)

**踩过的坑（勿重犯）**：

- ⚠️ **`strings` 查不到 Swift 字符串字面量 ≠ 代码没被编译/执行**。本轮据此误判为增量构建问题，白做一次 `clean build`，还让用户多复现两次。Swift 字符串在二进制里非明文。验证代码是否执行**只看运行时日志**。
- **抓 App NSLog 的正确姿势**：`xcrun simctl launch --console-pty booted com.Yuqi.dayfold > /tmp/x.log 2>&1 &`
  - `xcrun simctl spawn booted log stream --predicate ...` 抓不到 App 的 NSLog（本轮实测为空）
  - macOS **没有 `timeout` 命令**（GNU coreutils），用了会静默 `command not found` 导致启动命令根本没执行
- **改完必须重新 install**：构建成功 ≠ 模拟器上是新包。本轮因未重装，用户测的一直是旧包，"问题 1 仍存在"的反馈基于旧二进制。
- **绝不回读 `textContainer.size.width`** 来算 attachment 宽度：非滚动 UITextView 的 textContainer 会被超宽 attachment 反向撑宽，回读到的是已污染的值，拿去渲染下一张图会让宽度每次 layout 递增。只能用 `bounds.width` 减去自设的 `textContainerInset` + `lineFragmentPadding`。
- **宽度未就绪时不要用 `UIScreen.main.bounds.width` 兜底**：`updateUIView` 早于 `layoutSubviews`，此时 `bounds.width == 0`；用假宽度会预渲染错尺寸图片并污染 `lastUsedContainerWidth` 缓存判据。直接跳过，`layoutSubviews` 必然带真实宽度回来。
- **SourceKit 在 CLI 下报 `No such module 'UIKit'` 是误报**，以 `xcodebuild` 结果为准（CLAUDE.md 已记录）。
- 已与用户确认**不引入第三方富文本库**（swift-markdown-ui / MarkdownView 只读；RichTextKit 有 Backspace 删图 bug 且作者考虑停维）。

## 关键指针 (Pointers)

- 本轮改动：`dayfold/dayfold/Views/Entry/Components/SelectableTextEditor.swift`（override `intrinsicContentSize` 横向返回 `noIntrinsicMetric`）、`dayfold/dayfold/Services/RichTextMarkdownParser.swift`（高度上限 `safeWidth` → `safeWidth * 1.6` 修竖图压扁；宽度钳到 `safeWidth`）
- 阶段 H 全量改动清单与历史修复细节：见 git log `e753bb2`..`f2fa507`
- 记忆：`~/.claude/projects/-Users-rich1e-workspace-code-dayfold/memory/gotcha_uitextview-intrinsic-width.md`（含 strings 误判教训）
- 已知可忽略 Xcode 日志：`docs/XCODE_KNOWN_LOGS.md`（CoreData/CloudKit 134400 噪音）
- 构建命令见 `CLAUDE.md`；注意 `-project` 需绝对路径 `/Users/rich1e/workspace/code/dayfold/dayfold/dayfold.xcodeproj`（shell cwd 会在调用间重置）
