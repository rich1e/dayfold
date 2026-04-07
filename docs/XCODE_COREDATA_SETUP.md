# Core Data 实体定义指南

本指南将帮助你在 Xcode 中定义 Core Data 实体。模型扩展文件已经创建,现在需要在 Xcode 图形界面中定义实体。

## 前置条件

✅ 模型扩展文件已创建:
- `Models/Entry.swift`
- `Models/MediaAsset.swift`
- `Models/Location.swift`
- `Models/Tag.swift`

⚠️ 这些文件目前无法编译,需要先在 Xcode 中定义实体。

---

## 步骤 1: 打开 Core Data 模型编辑器

1. 在 Xcode 中打开项目 `/Users/rich1e/workspace/code/dayfold/dayfold/dayfold.xcodeproj`
2. 在左侧导航栏找到 `dayfold.xcdatamodeld` 文件
3. 点击打开,会显示 Core Data 模型编辑器

---

## 步骤 2: 创建 Entry 实体

### 2.1 添加实体
1. 点击底部的 **"Add Entity"** 按钮 (或按 `Cmd+N`)
2. 实体名称改为: `Entry`

### 2.2 添加属性
在右侧 Attributes 区域,点击 **"+"** 添加以下属性:

| 属性名 | 类型 | 可选 | 默认值 |
|--------|------|------|--------|
| `id` | UUID | ❌ | - |
| `title` | String | ✅ | - |
| `content` | String | ❌ | - |
| `createdAt` | Date | ❌ | - |
| `modifiedAt` | Date | ❌ | - |
| `isFavorite` | Boolean | ❌ | NO |
| `mood` | String | ✅ | - |
| `cloudKitRecordID` | String | ✅ | - |
| `needsSync` | Boolean | ❌ | NO |

### 2.3 添加关系
在右侧 Relationships 区域,点击 **"+"** 添加:

| 关系名 | 目标 | 类型 | 可选 | 逆向关系 | 删除规则 |
|--------|------|------|------|----------|----------|
| `mediaAssets` | MediaAsset | To Many | ✅ | entry | Cascade |
| `location` | Location | To One | ✅ | entry | Nullify |
| `tags` | Tag | To Many | ✅ | entries | Nullify |

---

## 步骤 3: 创建 MediaAsset 实体

### 3.1 添加实体
1. 再次点击 **"Add Entity"**
2. 实体名称改为: `MediaAsset`

### 3.2 添加属性

| 属性名 | 类型 | 可选 | 默认值 | 特殊设置 |
|--------|------|------|--------|----------|
| `id` | UUID | ❌ | - | - |
| `type` | String | ❌ | - | - |
| `filename` | String | ❌ | - | - |
| `thumbnailData` | Binary Data | ✅ | - | ✅ 勾选 "Allows External Storage" |
| `order` | Integer 32 | ❌ | 0 | - |
| `width` | Integer 32 | ❌ | 0 | - |
| `height` | Integer 32 | ❌ | 0 | - |
| `fileSize` | Integer 64 | ❌ | 0 | - |

### 3.3 添加关系

| 关系名 | 目标 | 类型 | 可选 | 逆向关系 | 删除规则 |
|--------|------|------|------|----------|----------|
| `entry` | Entry | To One | ✅ | mediaAssets | Nullify |

---

## 步骤 4: 创建 Location 实体

### 4.1 添加实体
1. 点击 **"Add Entity"**
2. 实体名称改为: `Location`

### 4.2 添加属性

| 属性名 | 类型 | 可选 | 默认值 |
|--------|------|------|--------|
| `id` | UUID | ❌ | - |
| `latitude` | Double | ❌ | 0 |
| `longitude` | Double | ❌ | 0 |
| `placeName` | String | ✅ | - |
| `address` | String | ✅ | - |
| `weatherTemperature` | Double | ❌ | 0 |
| `weatherCondition` | String | ✅ | - |
| `weatherIcon` | String | ✅ | - |

### 4.3 添加关系

| 关系名 | 目标 | 类型 | 可选 | 逆向关系 | 删除规则 |
|--------|------|------|------|----------|----------|
| `entry` | Entry | To One | ✅ | location | Nullify |

---

## 步骤 5: 创建 Tag 实体

### 5.1 添加实体
1. 点击 **"Add Entity"**
2. 实体名称改为: `Tag`

### 5.2 添加属性

| 属性名 | 类型 | 可选 | 默认值 |
|--------|------|------|--------|
| `id` | UUID | ❌ | - |
| `name` | String | ❌ | - |
| `color` | String | ❌ | - |
| `icon` | String | ✅ | - |
| `order` | Integer 32 | ❌ | 0 |

### 5.3 添加关系

| 关系名 | 目标 | 类型 | 可选 | 逆向关系 | 删除规则 |
|--------|------|------|------|----------|----------|
| `entries` | Entry | To Many | ✅ | tags | Nullify |

---

## 步骤 6: 配置 Codegen

为了让 Swift 扩展文件正常工作,需要配置代码生成:

1. 依次选择每个实体 (Entry, MediaAsset, Location, Tag)
2. 在右侧 Data Model Inspector 中找到 **"Codegen"** 选项
3. 将每个实体的 Codegen 设置为: **"Class Definition"**

这样 Xcode 会自动生成 NSManagedObject 类,你的扩展文件会扩展这些自动生成的类。

---

## 步骤 7: 保存和编译

1. 按 `Cmd+S` 保存模型文件
2. 按 `Cmd+B` 编译项目
3. **预期结果**: 编译成功,无错误

如果有编译错误,检查:
- 所有实体名称拼写正确
- 所有属性类型正确
- 关系配置正确
- Codegen 设置为 "Class Definition"

---

## 步骤 8: 验证

编译成功后,你应该能够:
- 在代码中使用 `Entry`, `MediaAsset`, `Location`, `Tag` 类
- 使用扩展方法如 `Entry.create(in:)`
- 访问便捷属性如 `entry.wrappedTitle`

---

## 完成后

当实体定义完成并编译成功后:

```bash
cd /Users/rich1e/workspace/code/dayfold/dayfold
git add dayfold.xcdatamodeld/
git commit -m "feat: define Core Data entities in model editor

- Create Entry entity with attributes and relationships
- Create MediaAsset entity for photos and videos
- Create Location entity with coordinates and weather
- Create Tag entity with name, color, and icon
- Configure all relationships with proper delete rules
- Set Codegen to Class Definition for all entities

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## 故障排除

### 问题: 编译错误 "Cannot find 'Entry' in scope"
**解决**: 确保 Codegen 设置为 "Class Definition" 并重新编译

### 问题: 关系属性类型错误
**解决**: 检查关系的目标实体和类型是否正确配置

### 问题: Optional 属性默认值
**解决**: 只有必填属性需要设置默认值,Optional 属性可以留空

---

## 参考

- [Apple Core Data 文档](https://developer.apple.com/documentation/coredata)
- 模型扩展文件位置: `/Users/rich1e/workspace/code/dayfold/dayfold/dayfold/Models/`
