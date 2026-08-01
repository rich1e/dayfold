# Stitch 设计稿导出 — re-dayfold

导出时间：2026-07-31
Stitch 项目：`re-dayfold`（Project ID `13633875149271731736`，PROJECT_DESIGN，MOBILE 390×884）

## 目录结构

```
re-dayfold/
├── README.md          # 本文件：屏幕清单 + 说明
├── DESIGN.md          # 设计系统（暖色深色主题、颜色/字体 token、组件规范）
├── screenshots/       # 14 张高清屏幕截图 PNG
└── html/              # 13 份 Stitch 生成的静态 HTML（可在浏览器直接打开）
```

## 屏幕清单（仅带正式 label 的最终稿）

| # | 文件名 | 屏幕标题 | Screen ID |
|---|--------|---------|-----------|
| 01 | fullscreen-photo-viewer | Dayfold - 全屏图片查看器 | `0bb61a462f3847cbab872ade414205c5` |
| 02 | trash-view | Dayfold - 回收站 | `1a603cf6c7de4c11acfe7380eedc9ea4` |
| 03 | timeline | Dayfold 时间轴 | `3386b0f33f6643f9ae1dd17471b980dd` |
| 04 | lock-screen | Dayfold - 锁屏页 | `3d2503292833484182afcb83c744a9e6` |
| 05 | photo-wall-gallery | Dayfold - 照片墙 | `3d2eb29401ed4da6be2228bbb93f6a98` |
| 06 | home-single-cover | Dayfold Home - 日记本画廊2 | `444ab6b2b57a486a95d33d604ef6a8e7` |
| 07 | navigation-drawer | Dayfold - 抽屉导航 | `560bd222ce7646998c984dcf708859f4` |
| 08 | calendar-entry-sheet | Dayfold - 日历条目表 | `5a56616a8b244e87a454b26203f6005f` |
| 09 | entry-card-export-preview | Dayfold - 分享卡片 | `5e0808ce759b427c8e812919af4588a8` |
| 10 | entry-detail-view | Dayfold - 日记详情页 | `bbc9c71944844632a5e0d2c03d3177c5` |
| 11 | calendar-view | Dayfold - 日历 | `c5a37fd0421b4ae085f788ef0d452b0f` |
| 12 | tag-management | Dayfold - 标签管理页 | `d812a490a67e41c2a127dc0a192ac58e` |
| 13 | map-view | Dayfold - 地图 | `e792f8e95da249e4981febebb93a4aee` |
| 14 | notebook-gallery | Dayfold Home - 日记本画廊 | `b64198532a554950b7f18d7aa395ce87` |

> 说明：`14-notebook-gallery` 是 SCREEN_INSTANCE 早期稿，仅有截图、无 HTML；其余 13 屏 PNG + HTML 齐全。
> 隐藏的迭代中间稿未导出（本次仅取带 label 的最终稿）。

## 备注

- Stitch MCP 的 `download_assets` 工具在本地环境下会返回"成功"但不实际落盘，因此本导出改用 `get_screen` 获取签名 URL + `curl` 抓取。
- 截图 URL 为 Google 存储的临时签名链接，会过期；如需重新导出，需重新调用 `get_screen`。
