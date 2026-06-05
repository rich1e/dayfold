# Dayfold

> 一款温暖文艺的 iOS 个人日记应用 —— 记录与回顾生活中的重要时刻。

Dayfold 专注于 iOS 平台，提供专业的写作体验、丰富的多媒体记录和完善的隐私保护。以暖色调的视觉风格，帮助你认真对待每一天的记录。

## ✨ 功能特性

### 快速记录
- 主界面一键创建新日记
- 草稿自动保存（每 2 秒）
- 自动获取当前位置与天气信息
- 快捷添加照片
- 日期、时间自动记录

### 深度写作
- Markdown 编辑器（加粗 / 斜体 / 列表 / 引用 / 链接 / 待办）
- 格式化工具栏
- 全屏专注模式
- 实时字数统计与预计阅读时间

### 多媒体与上下文
- 单篇最多 10 张照片，三列网格预览与全屏查看
- 位置与天气信息记录
- 自定义标签（颜色、图标、排序），支持多对多关联

### 多维度浏览
- **时间轴**：按日期分组浏览
- **日历**：月历网格，圆点标记当日记录（含图为暖橙、纯文字为暖棕），可拖拽底部抽屉查看当天条目
- **照片墙**：交错网格展示带图日记，收藏条目大图突出
- 收藏、搜索、按标签筛选

### 隐私与同步
- Face ID / Touch ID 应用锁
- 基于 iCloud 的跨设备自动同步（CloudKit）
- 无 iCloud 账号时自动降级为纯本地存储

## 🛠 技术栈

| 分类 | 技术 |
| ---- | ---- |
| UI 框架 | SwiftUI |
| 架构模式 | MVVM |
| 数据持久化 | Core Data + CloudKit（`NSPersistentCloudKitContainer`） |
| 并发模型 | Swift async/await + Combine |
| 图片选择 | PhotosUI（PhotosPicker） |
| 位置服务 | CoreLocation |
| 天气服务 | WeatherKit |
| 生物认证 | LocalAuthentication（Face ID / Touch ID） |
| 线程安全 | `@MainActor` 隔离 |

## 📁 项目结构

```
dayfold/
├── dayfoldApp.swift            # App 入口
├── Info.plist
├── dayfold.xcdatamodeld/       # Core Data 模型
├── Models/                     # Entry / MediaAsset / Location / Tag
├── Services/                   # CoreDataStack / Location / Weather / Media / Security
├── ViewModels/                 # EntryList / EntryEditor / Timeline / TagManager
├── Views/
│   ├── MainTabView.swift       # 三 Tab 导航（时间轴 / 全部 / 标签）
│   ├── LockScreenView.swift    # 锁屏
│   ├── Entry/                  # 列表 / 详情 / 编辑器及组件
│   ├── Timeline/               # 时间轴 / 日历 / 照片墙
│   ├── Tags/                   # 标签管理
│   └── Common/                 # 通用组件
└── Extensions/                 # 颜色 / 字体 / View 扩展
```

## 🚀 快速开始

### 环境要求
- Xcode 16+
- iOS 18.1+
- 启用 CloudKit / WeatherKit 需有效的 Apple Developer 账号

### 运行
```bash
git clone <repository-url>
cd dayfold/dayfold
open dayfold.xcodeproj
```
在 Xcode 中选择模拟器或真机，按 `Cmd + R` 运行。

> **CloudKit 同步**：需在模拟器或真机登录 iCloud 账号；未登录时应用会自动以纯本地模式运行，功能不受影响。

### 配置项

| 配置项 | 值 |
| ---- | ---- |
| Bundle ID | `com.Yuqi.dayfold` |
| iOS 部署目标 | 18.1 |
| CloudKit Container | `iCloud.com.Yuqi.dayfold` |
| 权限 | 位置、相册、Face ID、后台远程通知 |

如需用于自己的开发者账号，请在 Xcode 中修改 Bundle ID 与 CloudKit Container 标识符。

## 🏷 预设标签

应用首次启动自动创建：工作、生活、旅行、美食、运动、学习、娱乐。

## 📄 文档

- 设计规格：`docs/superpowers/specs/`
- 实现计划：`docs/superpowers/plans/`
- 实现进度：`docs/IMPLEMENTATION_PROGRESS.md`
- Core Data 配置指南：`docs/XCODE_COREDATA_SETUP.md`
- 可忽略的 Xcode 日志说明：`docs/XCODE_KNOWN_LOGS.md`

## 🤝 贡献

提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范，使用中文描述，例如：

```
feat: 添加日历模式月历网格
fix: 修复抽屉吸附高度计算
```

常用类型：`feat`、`fix`、`refactor`、`docs`、`chore`、`test`。

## 📝 许可证

本项目暂未声明开源许可证，版权归作者所有。
