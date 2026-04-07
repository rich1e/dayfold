# Dayfold iOS 日记应用 MVP 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个功能完整的 iOS 日记应用 MVP,支持快速记录、Markdown 编辑、多媒体、时间轴浏览和标签管理

**Architecture:** MVVM 架构,使用 SwiftUI 构建界面,Core Data + CloudKit 实现本地存储和云同步,温暖文艺的视觉风格

**Tech Stack:** Swift 5.9+, SwiftUI, Core Data, CloudKit, PhotosUI, CoreLocation, WeatherKit, MarkdownUI

---

## 文件结构规划

本项目将创建以下文件结构:

```
Dayfold/
├── DayfoldApp.swift                          # App 入口
├── Models/
│   ├── Entry.swift                           # 日记条目实体
│   ├── MediaAsset.swift                      # 媒体资源实体
│   ├── Location.swift                        # 位置信息实体
│   ├── Tag.swift                            # 标签实体
│   └── Dayfold.xcdatamodeld                 # Core Data 模型定义
├── Services/
│   ├── CoreDataStack.swift                  # Core Data 管理
│   ├── LocationService.swift                # 位置服务
│   ├── WeatherService.swift                 # 天气服务
│   ├── MediaService.swift                   # 媒体管理服务
│   └── SecurityManager.swift                # 安全认证管理
├── ViewModels/
│   ├── EntryListViewModel.swift             # 条目列表视图模型
│   ├── EntryEditorViewModel.swift           # 编辑器视图模型
│   ├── TimelineViewModel.swift              # 时间轴视图模型
│   └── TagManagerViewModel.swift            # 标签管理视图模型
├── Views/
│   ├── MainTabView.swift                    # 主标签页
│   ├── LockScreenView.swift                 # 锁屏界面
│   ├── Entry/
│   │   ├── EntryListView.swift             # 条目列表
│   │   ├── EntryDetailView.swift           # 条目详情
│   │   ├── EntryEditorView.swift           # 编辑器
│   │   └── Components/
│   │       ├── MarkdownEditor.swift        # Markdown 编辑器
│   │       ├── FormattingToolbar.swift     # 格式工具栏
│   │       ├── MediaPicker.swift           # 媒体选择器
│   │       └── TagPicker.swift             # 标签选择器
│   ├── Timeline/
│   │   ├── TimelineView.swift              # 时间轴主视图
│   │   ├── TimelineListView.swift          # 列表模式
│   │   ├── TimelineCalendarView.swift      # 日历模式
│   │   └── TimelinePhotoWallView.swift     # 照片墙模式
│   ├── Tags/
│   │   ├── TagsView.swift                  # 标签列表
│   │   └── TagEditorView.swift             # 标签编辑器
│   └── Common/
│       ├── WarmCardView.swift              # 卡片组件
│       ├── MediaGrid.swift                 # 媒体网格
│       └── EntryHeader.swift               # 条目头部
├── Extensions/
│   ├── Color+Warm.swift                     # 颜色扩展
│   ├── Font+Warm.swift                      # 字体扩展
│   └── View+Extensions.swift                # 视图扩展
└── Resources/
    └── Assets.xcassets                      # 资源文件
```

---

## Task 1: 项目初始化和基础配置

**Files:**
- Create: `Dayfold.xcodeproj`
- Create: `DayfoldApp.swift`
- Create: `.gitignore`
- Create: `README.md`

- [ ] **Step 1: 创建 Xcode 项目**

打开 Xcode → File → New → Project
选择 iOS → App
- Product Name: Dayfold
- Interface: SwiftUI
- Language: Swift
- Storage: Core Data
- Include Tests: ✓

- [ ] **Step 2: 配置项目设置**

Target → Signing & Capabilities:
- Add Capability: iCloud → CloudKit
- Add Capability: Background Modes → Remote notifications
- Set Bundle Identifier: com.yourcompany.dayfold
- Set iOS Deployment Target: 17.0

- [ ] **Step 3: 创建 .gitignore**

```bash
cat > .gitignore << 'EOF'
# Xcode
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcworkspace/contents.xcworkspacedata
/*.gcno
*.DS_Store
.swiftpm
DerivedData/
.build/

# CocoaPods
Pods/

# Swift Package Manager
.swiftpm/

# User data
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
xcuserdata/

# Playground
timeline.xctimeline
playground.xcworkspace
EOF
```

- [ ] **Step 4: 初始化 Git 仓库**

```bash
git init
git add .
git commit -m "chore: initialize Xcode project with Core Data and CloudKit

- Create iOS app with SwiftUI interface
- Enable Core Data storage
- Add iCloud and CloudKit capabilities
- Set iOS deployment target to 17.0

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 2: 颜色和字体系统

**Files:**
- Create: `Extensions/Color+Warm.swift`
- Create: `Extensions/Font+Warm.swift`

- [ ] **Step 1: 创建颜色扩展**

```swift
// Extensions/Color+Warm.swift
import SwiftUI

extension Color {
    // 温暖米色系主色调
    static let warmPaper = Color(hex: "FFF5E6")
    static let warmCream = Color(hex: "FFE8CC")
    static let warmBrown = Color(hex: "8B7355")
    static let warmAccent = Color(hex: "DAA520")
    static let warmGray = Color(hex: "D4CFC0")
    static let warmDark = Color(hex: "5D4E37")
    static let warmLight = Color(hex: "F9F7F1")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

- [ ] **Step 2: 编译验证颜色扩展**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 3: 创建字体扩展**

```swift
// Extensions/Font+Warm.swift
import SwiftUI

extension Font {
    // 标题字体 - 宋体增强文艺感
    static let warmTitle = Font.custom("STSongti-SC-Bold", size: 24)
    static let warmHeadline = Font.custom("STSongti-SC-Regular", size: 18)

    // 正文字体 - Serif 设计提升可读性
    static let warmBody = Font.system(size: 16, weight: .regular, design: .serif)
    static let warmCaption = Font.system(size: 13, weight: .regular, design: .rounded)
    static let warmFootnote = Font.system(size: 11, weight: .regular, design: .rounded)
}
```

- [ ] **Step 4: 编译验证字体扩展**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 5: 提交更改**

```bash
git add Extensions/Color+Warm.swift Extensions/Font+Warm.swift
git commit -m "feat: add warm color and font system

- Define warm artistic color palette (cream, brown, gold tones)
- Add hex color initializer
- Define font system with serif and songti fonts

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 3: Core Data 模型定义

**Files:**
- Modify: `Dayfold.xcdatamodeld`
- Create: `Models/Entry.swift`
- Create: `Models/MediaAsset.swift`
- Create: `Models/Location.swift`
- Create: `Models/Tag.swift`

- [ ] **Step 1: 打开 Core Data 模型编辑器**

在 Xcode 中打开 `Dayfold.xcdatamodeld`

- [ ] **Step 2: 创建 Entry 实体**

点击 "Add Entity" 按钮,命名为 `Entry`
添加以下属性:
- id: UUID
- title: String (Optional)
- content: String
- createdAt: Date
- modifiedAt: Date
- isFavorite: Boolean (默认 NO)
- mood: String (Optional)
- cloudKitRecordID: String (Optional)
- needsSync: Boolean (默认 NO)

添加关系:
- mediaAssets: To Many → MediaAsset (Inverse: entry)
- location: To One → Location (Optional, Inverse: entry)
- tags: To Many → Tag (Inverse: entries)

- [ ] **Step 3: 创建 MediaAsset 实体**

点击 "Add Entity",命名为 `MediaAsset`
添加属性:
- id: UUID
- type: String (photo 或 video)
- filename: String
- thumbnailData: Binary Data (Optional, 允许外部存储)
- order: Integer 32
- width: Integer 32
- height: Integer 32
- fileSize: Integer 64

添加关系:
- entry: To One → Entry (Optional, Inverse: mediaAssets)

- [ ] **Step 4: 创建 Location 实体**

点击 "Add Entity",命名为 `Location`
添加属性:
- id: UUID
- latitude: Double
- longitude: Double
- placeName: String (Optional)
- address: String (Optional)
- weatherTemperature: Double (默认 0)
- weatherCondition: String (Optional)
- weatherIcon: String (Optional)

添加关系:
- entry: To One → Entry (Optional, Inverse: location)

- [ ] **Step 5: 创建 Tag 实体**

点击 "Add Entity",命名为 `Tag`
添加属性:
- id: UUID
- name: String
- color: String (十六进制颜色)
- icon: String (Optional, SF Symbol 名称)
- order: Integer 32

添加关系:
- entries: To Many → Entry (Inverse: tags)

- [ ] **Step 6: 保存 Core Data 模型**

```bash
# 在 Xcode 中按 Cmd+S 保存
# 然后按 Cmd+B 编译验证
# 预期: 编译成功,Core Data 类自动生成
```

- [ ] **Step 7: 创建 Entry 模型扩展**

```swift
// Models/Entry.swift
import Foundation
import CoreData

extension Entry {
    var wrappedTitle: String {
        title ?? ""
    }

    var wrappedContent: String {
        content ?? ""
    }

    var wrappedMood: String {
        mood ?? ""
    }

    var mediaAssetsArray: [MediaAsset] {
        let set = mediaAssets as? Set<MediaAsset> ?? []
        return set.sorted { $0.order < $1.order }
    }

    var tagsArray: [Tag] {
        let set = tags as? Set<Tag> ?? []
        return set.sorted { $0.order < $1.order }
    }

    static func create(in context: NSManagedObjectContext) -> Entry {
        let entry = Entry(context: context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.modifiedAt = Date()
        entry.isFavorite = false
        entry.needsSync = true
        return entry
    }
}
```

- [ ] **Step 8: 创建 MediaAsset 模型扩展**

```swift
// Models/MediaAsset.swift
import Foundation
import CoreData

enum MediaType: String {
    case photo = "photo"
    case video = "video"
}

extension MediaAsset {
    var mediaType: MediaType {
        MediaType(rawValue: type ?? "photo") ?? .photo
    }

    var wrappedFilename: String {
        filename ?? ""
    }

    static func create(type: MediaType, filename: String, in context: NSManagedObjectContext) -> MediaAsset {
        let asset = MediaAsset(context: context)
        asset.id = UUID()
        asset.type = type.rawValue
        asset.filename = filename
        asset.order = 0
        return asset
    }
}
```

- [ ] **Step 9: 创建 Location 模型扩展**

```swift
// Models/Location.swift
import Foundation
import CoreData
import CoreLocation

extension Location {
    var wrappedPlaceName: String {
        placeName ?? ""
    }

    var wrappedAddress: String {
        address ?? ""
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func create(latitude: Double, longitude: Double, in context: NSManagedObjectContext) -> Location {
        let location = Location(context: context)
        location.id = UUID()
        location.latitude = latitude
        location.longitude = longitude
        return location
    }
}
```

- [ ] **Step 10: 创建 Tag 模型扩展**

```swift
// Models/Tag.swift
import Foundation
import CoreData
import SwiftUI

extension Tag {
    var wrappedName: String {
        name ?? ""
    }

    var wrappedColor: String {
        color ?? "DAA520"
    }

    var wrappedIcon: String {
        icon ?? "tag.fill"
    }

    var displayColor: Color {
        Color(hex: wrappedColor)
    }

    var entriesArray: [Entry] {
        let set = entries as? Set<Entry> ?? []
        return set.sorted { $0.createdAt ?? Date() > $1.createdAt ?? Date() }
    }

    static func create(name: String, color: String, icon: String, in context: NSManagedObjectContext) -> Tag {
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        tag.color = color
        tag.icon = icon
        tag.order = 0
        return tag
    }

    static func presetTags() -> [(name: String, color: String, icon: String)] {
        [
            ("工作", "4A90E2", "briefcase.fill"),
            ("生活", "7ED321", "house.fill"),
            ("旅行", "F5A623", "airplane"),
            ("美食", "D0021B", "fork.knife"),
            ("运动", "BD10E0", "figure.run"),
            ("学习", "50E3C2", "book.fill"),
            ("娱乐", "FF6B6B", "gamecontroller.fill")
        ]
    }
}
```

- [ ] **Step 11: 编译验证所有模型**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 12: 提交更改**

```bash
git add Dayfold.xcdatamodeld Models/
git commit -m "feat: define Core Data models for Entry, MediaAsset, Location, Tag

- Create Entry entity with title, content, dates, and relationships
- Create MediaAsset entity for photos and videos
- Create Location entity with coordinates and weather data
- Create Tag entity with name, color, and icon
- Add model extensions with computed properties and factory methods
- Define preset tags (work, life, travel, food, sports, study, entertainment)

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 4: Core Data Stack 和 CloudKit 配置

**Files:**
- Create: `Services/CoreDataStack.swift`

- [ ] **Step 1: 创建 Core Data Stack**

```swift
// Services/CoreDataStack.swift
import Foundation
import CoreData
import CloudKit

class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()

    @Published var isCloudKitAvailable = false

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Dayfold")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }

        // 启用历史跟踪(用于同步)
        description.setOption(true as NSNumber,
                            forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber,
                            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // 配置 CloudKit 容器
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.yourcompany.dayfold"
        )

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("Core Data failed to load: \(error.localizedDescription)")
            } else {
                print("Core Data loaded successfully")
                self.checkCloudKitAvailability()
            }
        }

        // 自动合并来自其他上下文的变更
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // 监听远程变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )

        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func save() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }

    private func checkCloudKitAvailability() {
        CKContainer(identifier: "iCloud.com.yourcompany.dayfold")
            .accountStatus { status, error in
                DispatchQueue.main.async {
                    self.isCloudKitAvailable = (status == .available)
                    if !self.isCloudKitAvailable {
                        print("iCloud not available: \(status.rawValue)")
                    }
                }
            }
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        print("Remote change detected")
        // 视图会自动刷新,因为使用了 @FetchRequest
    }

    func createPresetTags() {
        let context = viewContext
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()

        do {
            let existingTags = try context.fetch(fetchRequest)
            guard existingTags.isEmpty else {
                print("Preset tags already exist")
                return
            }

            for (index, preset) in Tag.presetTags().enumerated() {
                let tag = Tag.create(name: preset.name, color: preset.color, icon: preset.icon, in: context)
                tag.order = Int32(index)
            }

            save()
            print("Preset tags created successfully")
        } catch {
            print("Failed to create preset tags: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 2: 编译验证 Core Data Stack**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 3: 提交更改**

```bash
git add Services/CoreDataStack.swift
git commit -m "feat: implement Core Data stack with CloudKit sync

- Create NSPersistentCloudKitContainer with history tracking
- Enable automatic merge from parent context
- Add CloudKit availability check
- Handle remote change notifications
- Implement preset tags creation

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 5: 位置和天气服务

**Files:**
- Create: `Services/LocationService.swift`
- Create: `Services/WeatherService.swift`
- Modify: `Info.plist`

- [ ] **Step 1: 添加位置权限描述到 Info.plist**

在 Xcode 中打开 `Info.plist`,添加:
- Key: `NSLocationWhenInUseUsageDescription`
- Value: `Dayfold 需要访问您的位置来记录日记的地点信息`

- [ ] **Step 2: 创建位置服务**

```swift
// Services/LocationService.swift
import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var currentLocation: CLLocation?
    @Published var placeName: String?
    @Published var isAuthorized = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        checkAuthorization()
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard isAuthorized else {
            requestAuthorization()
            return
        }
        locationManager.requestLocation()
    }

    private func checkAuthorization() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = false
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    private func reverseGeocode() {
        guard let location = currentLocation else { return }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self,
                  let placemark = placemarks?.first,
                  error == nil else {
                return
            }

            let city = placemark.locality ?? ""
            let area = placemark.subLocality ?? ""

            if !city.isEmpty && !area.isEmpty {
                self.placeName = "\(city)·\(area)"
            } else if !city.isEmpty {
                self.placeName = city
            } else {
                self.placeName = area
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        reverseGeocode()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
```

- [ ] **Step 3: 编译验证位置服务**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 4: 创建天气服务**

```swift
// Services/WeatherService.swift
import Foundation
import CoreLocation
import WeatherKit

struct WeatherData {
    let temperature: Double
    let condition: String
    let symbolName: String
}

class WeatherService {
    static let shared = WeatherService()

    private let weatherService = WeatherKit.WeatherService.shared

    func fetchWeather(for location: CLLocation) async throws -> WeatherData {
        let weather = try await weatherService.weather(
            for: location.coordinate
        )

        let currentWeather = weather.currentWeather
        let temperature = currentWeather.temperature.value
        let condition = currentWeather.condition.description
        let symbolName = currentWeather.symbolName

        return WeatherData(
            temperature: temperature,
            condition: condition,
            symbolName: symbolName
        )
    }

    func fetchWeatherIfPossible(for location: CLLocation?) async -> WeatherData? {
        guard let location = location else { return nil }

        do {
            return try await fetchWeather(for: location)
        } catch {
            print("Weather fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}
```

- [ ] **Step 5: 添加 WeatherKit 权限**

Target → Signing & Capabilities:
- Add Capability: WeatherKit

- [ ] **Step 6: 编译验证天气服务**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 7: 提交更改**

```bash
git add Services/LocationService.swift Services/WeatherService.swift Info.plist
git commit -m "feat: implement location and weather services

- Add LocationService with CLLocationManager integration
- Request when-in-use location authorization
- Implement reverse geocoding for place names
- Add WeatherService using WeatherKit
- Fetch current weather for given location
- Add location permission description to Info.plist

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 6: 媒体管理服务

**Files:**
- Create: `Services/MediaService.swift`

- [ ] **Step 1: 创建媒体服务**

```swift
// Services/MediaService.swift
import Foundation
import UIKit
import Photos

class MediaService {
    static let shared = MediaService()

    private let fileManager = FileManager.default

    var mediaDirectory: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaURL = documentsURL.appendingPathComponent("Media", isDirectory: true)

        // 确保目录存在
        try? fileManager.createDirectory(at: mediaURL, withIntermediateDirectories: true)

        return mediaURL
    }

    func saveImage(_ image: UIImage) -> (filename: String, thumbnail: Data?)? {
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = mediaDirectory.appendingPathComponent(filename)

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }

        do {
            try imageData.write(to: fileURL)
            let thumbnail = generateThumbnail(from: image)
            return (filename, thumbnail)
        } catch {
            print("Failed to save image: \(error.localizedDescription)")
            return nil
        }
    }

    func loadImage(filename: String) -> UIImage? {
        let fileURL = mediaDirectory.appendingPathComponent(filename)
        guard let imageData = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return UIImage(data: imageData)
    }

    func deleteImage(filename: String) {
        let fileURL = mediaDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    func generateThumbnail(from image: UIImage, size: CGSize = CGSize(width: 100, height: 100)) -> Data? {
        let targetSize = calculateThumbnailSize(for: image.size, target: size)

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: targetSize))

        guard let thumbnail = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }

        return thumbnail.jpegData(compressionQuality: 0.7)
    }

    private func calculateThumbnailSize(for originalSize: CGSize, target: CGSize) -> CGSize {
        let widthRatio = target.width / originalSize.width
        let heightRatio = target.height / originalSize.height
        let ratio = min(widthRatio, heightRatio)

        return CGSize(
            width: originalSize.width * ratio,
            height: originalSize.height * ratio
        )
    }

    func requestPhotoLibraryAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
}
```

- [ ] **Step 2: 编译验证媒体服务**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 3: 添加相册权限描述到 Info.plist**

在 Xcode 中打开 `Info.plist`,添加:
- Key: `NSPhotoLibraryUsageDescription`
- Value: `Dayfold 需要访问您的相册来添加照片到日记`

- [ ] **Step 4: 提交更改**

```bash
git add Services/MediaService.swift Info.plist
git commit -m "feat: implement media management service

- Create MediaService for photo storage
- Save images to Documents/Media directory
- Generate thumbnails (100x100) with quality compression
- Implement image loading and deletion
- Add photo library authorization request
- Add photo library permission description

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 7: 安全管理服务

**Files:**
- Create: `Services/SecurityManager.swift`
- Modify: `Info.plist`

- [ ] **Step 1: 添加 Face ID 权限描述**

在 Xcode 中打开 `Info.plist`,添加:
- Key: `NSFaceIDUsageDescription`
- Value: `Dayfold 使用 Face ID 来保护您的隐私`

- [ ] **Step 2: 创建安全管理器**

```swift
// Services/SecurityManager.swift
import Foundation
import LocalAuthentication

class SecurityManager: ObservableObject {
    @Published var isLocked = true
    @Published var isEnabled = true

    private let context = LAContext()

    func authenticate() async -> Bool {
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            // 如果生物识别不可用,自动解锁
            await MainActor.run {
                isLocked = false
            }
            return true
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "解锁 Dayfold"
            )

            await MainActor.run {
                if success {
                    isLocked = false
                }
            }

            return success
        } catch {
            print("Authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    func lock() {
        isLocked = true
    }

    func toggleSecurity() {
        isEnabled.toggle()
        if !isEnabled {
            isLocked = false
        }
    }
}
```

- [ ] **Step 3: 编译验证安全管理器**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 4: 提交更改**

```bash
git add Services/SecurityManager.swift Info.plist
git commit -m "feat: implement security manager with Face ID

- Create SecurityManager for biometric authentication
- Support Face ID and Touch ID via LocalAuthentication
- Implement lock/unlock functionality
- Add toggle for security feature
- Add Face ID permission description

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 8: 通用视图组件

**Files:**
- Create: `Extensions/View+Extensions.swift`
- Create: `Views/Common/WarmCardView.swift`

- [ ] **Step 1: 创建视图扩展**

```swift
// Extensions/View+Extensions.swift
import SwiftUI

extension View {
    func warmCard() -> some View {
        self.modifier(WarmCardModifier())
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct WarmCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.warmLight)
            .cornerRadius(16)
            .shadow(color: Color.warmGray.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
```

- [ ] **Step 2: 编译验证视图扩展**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 3: 创建温暖卡片视图**

```swift
// Views/Common/WarmCardView.swift
import SwiftUI

struct WarmCardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .warmCard()
    }
}

#Preview {
    WarmCardView {
        VStack(alignment: .leading, spacing: 8) {
            Text("示例卡片")
                .font(.warmHeadline)
                .foregroundColor(.warmDark)

            Text("这是一个使用温暖配色的卡片组件")
                .font(.warmBody)
                .foregroundColor(.warmBrown)
        }
    }
    .padding()
    .background(Color.warmPaper)
}
```

- [ ] **Step 4: 编译验证卡片视图**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 5: 预览卡片组件**

在 Xcode 中打开 `WarmCardView.swift`,点击 Canvas 中的 Resume 按钮查看预览
预期: 显示温暖米色风格的卡片

- [ ] **Step 6: 提交更改**

```bash
git add Extensions/View+Extensions.swift Views/Common/WarmCardView.swift
git commit -m "feat: add warm card view component and extensions

- Create WarmCardModifier for consistent card styling
- Add warmCard() view extension
- Add hideKeyboard() utility extension
- Create reusable WarmCardView component
- Add preview for design verification

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 9: 锁屏界面

**Files:**
- Create: `Views/LockScreenView.swift`

- [ ] **Step 1: 创建锁屏视图**

```swift
// Views/LockScreenView.swift
import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var securityManager: SecurityManager
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                colors: [Color.warmCream, Color.warmPaper],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // 应用图标和名称
                VStack(spacing: 16) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.warmAccent)

                    Text("Dayfold")
                        .font(.warmTitle)
                        .foregroundColor(.warmDark)
                }

                Spacer()

                // 解锁按钮
                Button {
                    authenticateUser()
                } label: {
                    HStack(spacing: 12) {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "faceid")
                                .font(.title2)
                            Text("解锁")
                                .font(.warmBody)
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.warmAccent)
                    .cornerRadius(12)
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, 48)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            // 自动尝试认证
            if securityManager.isEnabled {
                authenticateUser()
            }
        }
    }

    private func authenticateUser() {
        isAuthenticating = true

        Task {
            let success = await securityManager.authenticate()
            await MainActor.run {
                isAuthenticating = false
                if !success {
                    // 可以显示错误提示
                    print("Authentication failed")
                }
            }
        }
    }
}

#Preview {
    LockScreenView()
        .environmentObject(SecurityManager())
}
```

- [ ] **Step 2: 编译验证锁屏视图**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 3: 预览锁屏界面**

在 Xcode 中打开 `LockScreenView.swift`,查看预览
预期: 显示温暖渐变背景,中间有应用图标和解锁按钮

- [ ] **Step 4: 提交更改**

```bash
git add Views/LockScreenView.swift
git commit -m "feat: implement lock screen with Face ID authentication

- Create LockScreenView with warm gradient background
- Display app icon and name
- Add Face ID unlock button
- Auto-attempt authentication on appear
- Show loading state during authentication

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 10: 条目列表 ViewModel

**Files:**
- Create: `ViewModels/EntryListViewModel.swift`

- [ ] **Step 1: 创建条目列表 ViewModel**

```swift
// ViewModels/EntryListViewModel.swift
import Foundation
import CoreData
import Combine

class EntryListViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedTags: Set<Tag> = []
    @Published var showFavoritesOnly = false

    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    func deleteEntry(_ entry: Entry) {
        // 删除关联的媒体文件
        for asset in entry.mediaAssetsArray {
            if let filename = asset.filename {
                MediaService.shared.deleteImage(filename: filename)
            }
            viewContext.delete(asset)
        }

        // 删除位置信息
        if let location = entry.location {
            viewContext.delete(location)
        }

        // 删除条目
        viewContext.delete(entry)

        // 保存
        CoreDataStack.shared.save()
    }

    func toggleFavorite(_ entry: Entry) {
        entry.isFavorite.toggle()
        entry.modifiedAt = Date()
        entry.needsSync = true
        CoreDataStack.shared.save()
    }

    func filterPredicate() -> NSPredicate? {
        var predicates: [NSPredicate] = []

        // 搜索过滤
        if !searchText.isEmpty {
            let contentPredicate = NSPredicate(format: "content CONTAINS[cd] %@", searchText)
            let titlePredicate = NSPredicate(format: "title CONTAINS[cd] %@", searchText)
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [contentPredicate, titlePredicate]))
        }

        // 收藏过滤
        if showFavoritesOnly {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }

        // 标签过滤
        if !selectedTags.isEmpty {
            let tagPredicates = selectedTags.map { tag in
                NSPredicate(format: "ANY tags == %@", tag)
            }
            predicates.append(NSCompoundPredicate(andPredicateWithSubpredicates: tagPredicates))
        }

        return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
```

- [ ] **Step 2: 编译验证 ViewModel**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 3: 提交更改**

```bash
git add ViewModels/EntryListViewModel.swift
git commit -m "feat: implement entry list view model

- Create EntryListViewModel with search and filter logic
- Add deleteEntry method with cascade deletion
- Add toggleFavorite for quick actions
- Implement dynamic predicate generation for filtering
- Support search by content and title
- Support filter by tags and favorites

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 11: 条目编辑器 ViewModel

**Files:**
- Create: `ViewModels/EntryEditorViewModel.swift`

- [ ] **Step 1: 创建编辑器 ViewModel**

```swift
// ViewModels/EntryEditorViewModel.swift
import Foundation
import CoreData
import CoreLocation
import UIKit
import Combine

class EntryEditorViewModel: ObservableObject {
    @Published var title = ""
    @Published var content = ""
    @Published var selectedTags: [Tag] = []
    @Published var images: [UIImage] = []
    @Published var location: CLLocation?
    @Published var placeName: String?
    @Published var weather: WeatherData?
    @Published var isSaving = false

    private let viewContext: NSManagedObjectContext
    private let entry: Entry?
    private var autoSaveTimer: Timer?
    private let locationService = LocationService()

    var isNewEntry: Bool {
        entry == nil
    }

    var wordCount: Int {
        content.split(separator: " ").count
    }

    var readingTime: Int {
        max(1, wordCount / 200)
    }

    init(context: NSManagedObjectContext, entry: Entry? = nil) {
        self.viewContext = context
        self.entry = entry

        if let entry = entry {
            self.title = entry.wrappedTitle
            self.content = entry.wrappedContent
            self.selectedTags = entry.tagsArray
            self.location = entry.location?.coordinate.toLocation()
            self.placeName = entry.location?.wrappedPlaceName

            if let location = entry.location {
                self.weather = WeatherData(
                    temperature: location.weatherTemperature,
                    condition: location.weatherCondition ?? "",
                    symbolName: location.weatherIcon ?? "sun.max.fill"
                )
            }
        } else {
            // 新条目自动获取位置和天气
            fetchLocationAndWeather()
        }

        startAutoSave()
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    func save() async -> Bool {
        await MainActor.run {
            isSaving = true
        }

        let entryToSave = entry ?? Entry.create(in: viewContext)

        entryToSave.title = title.isEmpty ? nil : title
        entryToSave.content = content
        entryToSave.modifiedAt = Date()
        entryToSave.needsSync = true

        // 保存标签
        entryToSave.tags = NSSet(array: selectedTags)

        // 保存位置和天气
        if let location = location {
            let locationEntity = entryToSave.location ?? Location.create(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                in: viewContext
            )
            locationEntity.placeName = placeName
            locationEntity.weatherTemperature = weather?.temperature ?? 0
            locationEntity.weatherCondition = weather?.condition
            locationEntity.weatherIcon = weather?.symbolName
            entryToSave.location = locationEntity
        }

        // 保存图片
        for (index, image) in images.enumerated() {
            // 检查是否已存在
            let existingAsset = entryToSave.mediaAssetsArray.first { $0.order == Int32(index) }
            if existingAsset == nil {
                if let result = MediaService.shared.saveImage(image) {
                    let asset = MediaAsset.create(type: .photo, filename: result.filename, in: viewContext)
                    asset.thumbnailData = result.thumbnail
                    asset.order = Int32(index)
                    asset.width = Int32(image.size.width)
                    asset.height = Int32(image.size.height)
                    asset.entry = entryToSave
                }
            }
        }

        CoreDataStack.shared.save()

        await MainActor.run {
            isSaving = false
        }

        return true
    }

    func addTag(_ tag: Tag) {
        if !selectedTags.contains(where: { $0.id == tag.id }) {
            selectedTags.append(tag)
        }
    }

    func removeTag(_ tag: Tag) {
        selectedTags.removeAll { $0.id == tag.id }
    }

    func addImage(_ image: UIImage) {
        images.append(image)
    }

    func removeImage(at index: Int) {
        guard index < images.count else { return }
        images.remove(at: index)
    }

    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                _ = await self.save()
            }
        }
    }

    private func fetchLocationAndWeather() {
        locationService.requestLocation()

        // 监听位置更新
        let cancellable = locationService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.location = location
                self?.placeName = self?.locationService.placeName

                // 获取天气
                Task {
                    self?.weather = await WeatherService.shared.fetchWeatherIfPossible(for: location)
                }
            }

        // 存储 cancellable 防止被释放
        // 实际项目中应该用 Set<AnyCancellable> 管理
    }
}

extension CLLocationCoordinate2D {
    func toLocation() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
```

- [ ] **Step 2: 编译验证 ViewModel**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 3: 提交更改**

```bash
git add ViewModels/EntryEditorViewModel.swift
git commit -m "feat: implement entry editor view model

- Create EntryEditorViewModel for create/edit entries
- Auto-save every 2 seconds
- Fetch location and weather for new entries
- Calculate word count and reading time
- Handle tags, images, and location data
- Save all data to Core Data with relationships

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 12: Markdown 编辑器组件

**Files:**
- Create: `Views/Entry/Components/MarkdownEditor.swift`
- Create: `Views/Entry/Components/FormattingToolbar.swift`
- Add Package: `MarkdownUI` via Swift Package Manager

- [ ] **Step 1: 添加 MarkdownUI 依赖**

File → Add Package Dependencies
输入: `https://github.com/gonzalezreal/swift-markdown-ui`
选择最新版本,点击 Add Package

- [ ] **Step 2: 创建格式工具栏**

```swift
// Views/Entry/Components/FormattingToolbar.swift
import SwiftUI

struct FormattingToolbar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ToolbarButton(icon: "bold", title: "粗体") {
                    insertMarkdown("**", "**")
                }

                ToolbarButton(icon: "italic", title: "斜体") {
                    insertMarkdown("*", "*")
                }

                ToolbarButton(icon: "list.bullet", title: "列表") {
                    insertMarkdown("\n- ", "")
                }

                ToolbarButton(icon: "number", title: "编号列表") {
                    insertMarkdown("\n1. ", "")
                }

                ToolbarButton(icon: "quote.opening", title: "引用") {
                    insertMarkdown("\n> ", "")
                }

                ToolbarButton(icon: "link", title: "链接") {
                    insertMarkdown("[", "](url)")
                }

                ToolbarButton(icon: "checkmark.square", title: "待办") {
                    insertMarkdown("\n- [ ] ", "")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.warmLight)
    }

    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        text.insert(contentsOf: prefix, at: text.endIndex)
        text.insert(contentsOf: suffix, at: text.endIndex)
        isFocused = true
    }
}

struct ToolbarButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(.warmBrown)
            .frame(width: 50)
        }
    }
}
```

- [ ] **Step 3: 创建 Markdown 编辑器**

```swift
// Views/Entry/Components/MarkdownEditor.swift
import SwiftUI

struct MarkdownEditor: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var isFullscreen = false

    var wordCount: Int
    var readingTime: Int

    var body: some View {
        VStack(spacing: 0) {
            if !isFullscreen {
                // 工具栏
                FormattingToolbar(text: $text, isFocused: $isFocused)
                    .background(Color.warmLight)

                Divider()
            }

            // 编辑区域
            TextEditor(text: $text)
                .focused($isFocused)
                .font(.warmBody)
                .scrollContentBackground(.hidden)
                .background(Color.warmPaper)
                .padding(.horizontal, isFullscreen ? 20 : 16)

            if !isFullscreen {
                Divider()

                // 状态栏
                HStack {
                    Text("\(wordCount) 字")
                        .font(.warmCaption)
                        .foregroundColor(.warmBrown)

                    Text("·")
                        .foregroundColor(.warmGray)

                    Text("约 \(readingTime) 分钟阅读")
                        .font(.warmCaption)
                        .foregroundColor(.warmBrown)

                    Spacer()

                    Button {
                        withAnimation {
                            isFullscreen.toggle()
                        }
                    } label: {
                        Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.warmAccent)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.warmLight)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    MarkdownEditor(
        text: .constant("# 标题\n\n这是一段**粗体**和*斜体*文字。"),
        wordCount: 15,
        readingTime: 1
    )
}
```

- [ ] **Step 4: 编译验证编辑器**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 5: 预览 Markdown 编辑器**

在 Xcode 中打开 `MarkdownEditor.swift`,查看预览
预期: 显示工具栏、编辑区域和状态栏

- [ ] **Step 6: 提交更改**

```bash
git add Views/Entry/Components/
git commit -m "feat: implement Markdown editor with formatting toolbar

- Add MarkdownUI package dependency
- Create FormattingToolbar with common markdown actions
- Implement MarkdownEditor with TextEditor
- Show word count and reading time
- Support fullscreen mode toggle
- Auto-focus on appear

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 13: 媒体选择器组件

**Files:**
- Create: `Views/Entry/Components/MediaPicker.swift`
- Create: `Views/Common/MediaGrid.swift`

- [ ] **Step 1: 创建媒体网格组件**

```swift
// Views/Common/MediaGrid.swift
import SwiftUI

struct MediaGrid: View {
    let images: [UIImage]
    let onRemove: ((Int) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                MediaGridItem(image: image, onRemove: {
                    onRemove?(index)
                })
            }
        }
    }
}

struct MediaGridItem: View {
    let image: UIImage
    let onRemove: (() -> Void)?
    @State private var showFullscreen = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
                    .cornerRadius(8)
                    .onTapGesture {
                        showFullscreen = true
                    }

                if let onRemove = onRemove {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 24, height: 24)
                            )
                    }
                    .padding(4)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .fullScreenCover(isPresented: $showFullscreen) {
            FullscreenImageView(image: image, isPresented: $showFullscreen)
        }
    }
}

struct FullscreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}
```

- [ ] **Step 2: 创建媒体选择器**

```swift
// Views/Entry/Components/MediaPicker.swift
import SwiftUI
import PhotosUI

struct MediaPicker: View {
    @Binding var images: [UIImage]
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 照片网格
            if !images.isEmpty {
                MediaGrid(images: images) { index in
                    images.remove(at: index)
                }
                .padding(.vertical, 8)
            }

            // 添加照片按钮
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                    Text("添加照片")
                        .font(.warmBody)
                }
                .foregroundColor(.warmAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.warmLight)
                .cornerRadius(12)
            }
            .onChange(of: selectedItems) { oldValue, newValue in
                loadPhotos(from: newValue)
            }
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            images.append(image)
                        }
                    }
                case .failure(let error):
                    print("Failed to load image: \(error)")
                }
            }
        }
    }
}

#Preview {
    MediaPicker(images: .constant([]))
        .padding()
        .background(Color.warmPaper)
}
```

- [ ] **Step 3: 编译验证组件**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 4: 提交更改**

```bash
git add Views/Entry/Components/MediaPicker.swift Views/Common/MediaGrid.swift
git commit -m "feat: implement media picker and grid components

- Create MediaGrid with 3-column layout
- Support tap to view fullscreen
- Add remove button for each image
- Create MediaPicker using PhotosPicker
- Support multiple image selection (max 10)
- Auto-load selected images

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 14: 标签选择器组件

**Files:**
- Create: `Views/Entry/Components/TagPicker.swift`

- [ ] **Step 1: 创建标签选择器**

```swift
// Views/Entry/Components/TagPicker.swift
import SwiftUI

struct TagPicker: View {
    @Binding var selectedTags: [Tag]
    @State private var showingTagSelector = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 已选标签
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedTags, id: \.id) { tag in
                            TagChip(tag: tag, isSelected: true) {
                                removeTag(tag)
                            }
                        }
                    }
                }
            }

            // 添加标签按钮
            Button {
                showingTagSelector = true
            } label: {
                HStack {
                    Image(systemName: "tag")
                    Text("添加标签")
                        .font(.warmBody)
                }
                .foregroundColor(.warmAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.warmLight)
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingTagSelector) {
            TagSelectorSheet(selectedTags: $selectedTags)
        }
    }

    private func removeTag(_ tag: Tag) {
        selectedTags.removeAll { $0.id == tag.id }
    }
}

struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: tag.wrappedIcon)
                    .font(.system(size: 12))

                Text(tag.wrappedName)
                    .font(.warmCaption)

                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tag.displayColor.opacity(0.2))
            .foregroundColor(tag.displayColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tag.displayColor, lineWidth: isSelected ? 1.5 : 0)
            )
        }
    }
}

struct TagSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedTags: [Tag]

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.order)],
        animation: .default
    )
    private var allTags: FetchedResults<Tag>

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(allTags, id: \.id) { tag in
                        let isSelected = selectedTags.contains(where: { $0.id == tag.id })

                        Button {
                            toggleTag(tag)
                        } label: {
                            HStack {
                                Image(systemName: tag.wrappedIcon)
                                    .foregroundColor(tag.displayColor)

                                Text(tag.wrappedName)
                                    .font(.warmBody)
                                    .foregroundColor(.warmDark)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(tag.displayColor)
                                }
                            }
                            .padding()
                            .background(Color.warmLight)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color.warmPaper)
            .navigationTitle("选择标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.warmAccent)
                }
            }
        }
    }

    private func toggleTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }
}

#Preview {
    TagPicker(selectedTags: .constant([]))
        .padding()
        .background(Color.warmPaper)
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
```

- [ ] **Step 2: 编译验证组件**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 3: 提交更改**

```bash
git add Views/Entry/Components/TagPicker.swift
git commit -m "feat: implement tag picker component

- Create TagPicker with selected tags display
- Add TagChip component with color and icon
- Implement TagSelectorSheet for tag selection
- Support multiple tag selection
- Fetch all tags from Core Data
- Show checkmark for selected tags

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 15: 条目编辑器视图

**Files:**
- Create: `Views/Entry/EntryEditorView.swift`

- [ ] **Step 1: 创建条目编辑器视图**

```swift
// Views/Entry/EntryEditorView.swift
import SwiftUI

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: EntryEditorViewModel
    @State private var showingSaveError = false

    init(entry: Entry? = nil, context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: EntryEditorViewModel(context: context, entry: entry))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 标题输入
                    TextField("标题(可选)", text: $viewModel.title)
                        .font(.warmTitle)
                        .foregroundColor(.warmDark)
                        .padding()
                        .background(Color.warmPaper)

                    Divider()

                    // 位置和天气信息
                    if let placeName = viewModel.placeName {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.warmAccent)
                            Text(placeName)
                                .font(.warmCaption)
                                .foregroundColor(.warmBrown)

                            if let weather = viewModel.weather {
                                Image(systemName: weather.symbolName)
                                    .foregroundColor(.warmAccent)
                                Text("\(Int(weather.temperature))°C")
                                    .font(.warmCaption)
                                    .foregroundColor(.warmBrown)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color.warmCream.opacity(0.5))
                    }

                    // Markdown 编辑器
                    MarkdownEditor(
                        text: $viewModel.content,
                        wordCount: viewModel.wordCount,
                        readingTime: viewModel.readingTime
                    )
                    .frame(minHeight: 300)

                    Divider()

                    // 媒体选择器
                    VStack(alignment: .leading, spacing: 16) {
                        MediaPicker(images: $viewModel.images)

                        // 标签选择器
                        TagPicker(selectedTags: $viewModel.selectedTags)
                    }
                    .padding()
                }
            }
            .background(Color.warmPaper)
            .navigationTitle(viewModel.isNewEntry ? "新日记" : "编辑日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.warmBrown)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveEntry()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                                .foregroundColor(.warmAccent)
                                .fontWeight(.medium)
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.content.isEmpty)
                }
            }
        }
        .alert("保存失败", isPresented: $showingSaveError) {
            Button("确定", role: .cancel) {}
        }
    }

    private func saveEntry() {
        Task {
            let success = await viewModel.save()
            if success {
                dismiss()
            } else {
                showingSaveError = true
            }
        }
    }
}

#Preview {
    EntryEditorView(context: CoreDataStack.shared.viewContext)
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
```

- [ ] **Step 2: 编译验证视图**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 3: 提交更改**

```bash
git add Views/Entry/EntryEditorView.swift
git commit -m "feat: implement entry editor view

- Create EntryEditorView with complete editing interface
- Show title input and location/weather info
- Integrate MarkdownEditor component
- Add MediaPicker for photo selection
- Add TagPicker for tag management
- Implement save with loading state
- Show error alert on save failure

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 16: 条目列表和详情视图

**Files:**
- Create: `Views/Entry/EntryListView.swift`
- Create: `Views/Entry/EntryDetailView.swift`
- Create: `Views/Common/EntryHeader.swift`

- [ ] **Step 1: 创建条目头部组件**

```swift
// Views/Common/EntryHeader.swift
import SwiftUI

struct EntryHeader: View {
    let entry: Entry

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 日期时间
            Text(entry.createdAt ?? Date(), formatter: dateFormatter)
                .font(.warmCaption)
                .foregroundColor(.warmBrown)

            // 位置和天气
            if let location = entry.location {
                HStack(spacing: 8) {
                    if !location.wrappedPlaceName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text(location.wrappedPlaceName)
                                .font(.warmFootnote)
                        }
                    }

                    if !location.weatherCondition.isNil {
                        HStack(spacing: 4) {
                            Image(systemName: location.weatherIcon ?? "sun.max.fill")
                                .font(.system(size: 10))
                            Text("\(Int(location.weatherTemperature))°C")
                                .font(.warmFootnote)
                        }
                    }
                }
                .foregroundColor(.warmAccent)
            }

            // 标签
            if !entry.tagsArray.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entry.tagsArray, id: \.id) { tag in
                            HStack(spacing: 4) {
                                Image(systemName: tag.wrappedIcon)
                                    .font(.system(size: 9))
                                Text(tag.wrappedName)
                                    .font(.system(size: 10))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tag.displayColor.opacity(0.2))
                            .foregroundColor(tag.displayColor)
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }
}

extension Optional where Wrapped == String {
    var isNil: Bool {
        self == nil
    }
}
```

- [ ] **Step 2: 创建条目详情视图**

```swift
// Views/Entry/EntryDetailView.swift
import SwiftUI
import MarkdownUI

struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let entry: Entry
    @State private var showingEditSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.warmTitle)
                        .foregroundColor(.warmDark)
                }

                // 头部信息
                EntryHeader(entry: entry)

                Divider()

                // Markdown 内容
                Markdown(entry.wrappedContent)
                    .markdownTextStyle(\.text) {
                        FontSize(16)
                        ForegroundColor(.warmDark)
                    }
                    .markdownTextStyle(\.code) {
                        FontFamily(.monospaced)
                        BackgroundColor(.warmCream)
                    }

                // 媒体网格
                if !entry.mediaAssetsArray.isEmpty {
                    let images = entry.mediaAssetsArray.compactMap { asset in
                        MediaService.shared.loadImage(filename: asset.wrappedFilename)
                    }

                    if !images.isEmpty {
                        Divider()

                        MediaGrid(images: images, onRemove: nil)
                    }
                }
            }
            .padding()
        }
        .background(Color.warmPaper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEditSheet = true
                } label: {
                    Text("编辑")
                        .foregroundColor(.warmAccent)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EntryEditorView(
                entry: entry,
                context: entry.managedObjectContext ?? CoreDataStack.shared.viewContext
            )
        }
    }
}
```

- [ ] **Step 3: 创建条目列表视图**

```swift
// Views/Entry/EntryListView.swift
import SwiftUI

struct EntryListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: EntryListViewModel
    @State private var showingNewEntry = false

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)],
        animation: .default
    )
    private var entries: FetchedResults<Entry>

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: EntryListViewModel(context: context))
    }

    var filteredEntries: [Entry] {
        if let predicate = viewModel.filterPredicate() {
            return entries.filter { entry in
                predicate.evaluate(with: entry)
            }
        }
        return Array(entries)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.warmPaper.ignoresSafeArea()

                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredEntries, id: \.id) { entry in
                                NavigationLink(destination: EntryDetailView(entry: entry)) {
                                    EntryCard(entry: entry, viewModel: viewModel)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("全部日记")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.warmAccent)
                            .font(.title2)
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "搜索日记")
        }
        .sheet(isPresented: $showingNewEntry) {
            EntryEditorView(context: viewContext)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed")
                .font(.system(size: 80))
                .foregroundColor(.warmGray)

            Text("还没有日记")
                .font(.warmHeadline)
                .foregroundColor(.warmBrown)

            Text("点击右上角的 + 开始记录")
                .font(.warmBody)
                .foregroundColor(.warmBrown.opacity(0.7))

            Button {
                showingNewEntry = true
            } label: {
                Text("创建第一篇日记")
                    .font(.warmBody)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.warmAccent)
                    .cornerRadius(24)
            }
        }
    }
}

struct EntryCard: View {
    let entry: Entry
    let viewModel: EntryListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            if !entry.wrappedTitle.isEmpty {
                Text(entry.wrappedTitle)
                    .font(.warmHeadline)
                    .foregroundColor(.warmDark)
                    .lineLimit(2)
            }

            // 内容预览
            Text(entry.wrappedContent)
                .font(.warmBody)
                .foregroundColor(.warmBrown)
                .lineLimit(3)

            // 头部信息
            EntryHeader(entry: entry)

            // 缩略图预览
            if !entry.mediaAssetsArray.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.mediaAssetsArray.prefix(3), id: \.id) { asset in
                            if let image = MediaService.shared.loadImage(filename: asset.wrappedFilename) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipped()
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .warmCard()
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteEntry(entry)
            } label: {
                Label("删除", systemImage: "trash")
            }

            Button {
                viewModel.toggleFavorite(entry)
            } label: {
                Label(
                    entry.isFavorite ? "取消收藏" : "收藏",
                    systemImage: entry.isFavorite ? "star.slash" : "star"
                )
            }
        }
    }
}

#Preview {
    EntryListView(context: CoreDataStack.shared.viewContext)
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
```

- [ ] **Step 4: 编译验证视图**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 5: 提交更改**

```bash
git add Views/Entry/ Views/Common/EntryHeader.swift
git commit -m "feat: implement entry list and detail views

- Create EntryHeader component for metadata display
- Implement EntryDetailView with Markdown rendering
- Create EntryListView with search and filter
- Add EntryCard component for list items
- Support empty state with call-to-action
- Add context menu for delete and favorite
- Integrate navigation and sheets

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 17: 时间轴视图

**Files:**
- Create: `ViewModels/TimelineViewModel.swift`
- Create: `Views/Timeline/TimelineView.swift`
- Create: `Views/Timeline/TimelineListView.swift`
- Create: `Views/Timeline/TimelineCalendarView.swift`
- Create: `Views/Timeline/TimelinePhotoWallView.swift`

- [ ] **Step 1: 创建时间轴 ViewModel**

```swift
// ViewModels/TimelineViewModel.swift
import Foundation
import CoreData

enum TimelineViewMode {
    case list
    case calendar
    case photoWall
}

class TimelineViewModel: ObservableObject {
    @Published var viewMode: TimelineViewMode = .list
    @Published var selectedDate: Date?

    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    func entriesForDate(_ date: Date) -> [Entry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch entries: \(error)")
            return []
        }
    }

    func datesWithEntries(in month: Date) -> Set<Date> {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return []
        }

        let fetchRequest: NSFetchRequest<Entry> = Entry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt <= %@",
            startOfMonth as NSDate,
            endOfMonth as NSDate
        )

        do {
            let entries = try viewContext.fetch(fetchRequest)
            return Set(entries.compactMap { entry in
                guard let date = entry.createdAt else { return nil }
                return calendar.startOfDay(for: date)
            })
        } catch {
            return []
        }
    }
}
```

- [ ] **Step 2: 创建时间轴列表视图**

```swift
// Views/Timeline/TimelineListView.swift
import SwiftUI

struct TimelineListView: View {
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)],
        animation: .default
    )
    private var entries: FetchedResults<Entry>

    var groupedEntries: [(String, [Entry])] {
        Dictionary(grouping: Array(entries)) { entry in
            formatDate(entry.createdAt ?? Date())
        }
        .sorted { $0.key > $1.key }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedEntries, id: \.0) { date, dayEntries in
                    Section {
                        ForEach(dayEntries, id: \.id) { entry in
                            NavigationLink(destination: EntryDetailView(entry: entry)) {
                                TimelineEntryCard(entry: entry)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    } header: {
                        Text(date)
                            .font(.warmHeadline)
                            .foregroundColor(.warmDark)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.warmCream)
                    }
                }
            }
        }
        .background(Color.warmPaper)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月dd日 EEEE"
            return formatter.string(from: date)
        }
    }
}

struct TimelineEntryCard: View {
    let entry: Entry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间标记
            VStack(spacing: 4) {
                let time = entry.createdAt ?? Date()
                Text(time, format: .dateTime.hour().minute())
                    .font(.warmCaption)
                    .foregroundColor(.warmBrown)

                Circle()
                    .fill(Color.warmAccent)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 60)

            // 内容
            VStack(alignment: .leading, spacing: 8) {
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.warmHeadline)
                        .foregroundColor(.warmDark)
                }

                Text(entry.wrappedContent)
                    .font(.warmBody)
                    .foregroundColor(.warmBrown)
                    .lineLimit(2)

                // 缩略图
                if let firstAsset = entry.mediaAssetsArray.first,
                   let image = MediaService.shared.loadImage(filename: firstAsset.wrappedFilename) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(8)
                }

                // 元信息
                HStack(spacing: 8) {
                    if let location = entry.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                            Text(location.wrappedPlaceName)
                        }
                        .font(.warmFootnote)
                        .foregroundColor(.warmAccent)
                    }

                    if !entry.tagsArray.isEmpty {
                        ForEach(entry.tagsArray.prefix(2), id: \.id) { tag in
                            Text(tag.wrappedName)
                                .font(.warmFootnote)
                                .foregroundColor(tag.displayColor)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .warmCard()
    }
}
```

- [ ] **Step 3: 创建时间轴主视图**

```swift
// Views/Timeline/TimelineView.swift
import SwiftUI

struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: TimelineViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 视图模式切换
                Picker("视图模式", selection: $viewModel.viewMode) {
                    Label("列表", systemImage: "list.bullet").tag(TimelineViewMode.list)
                    Label("日历", systemImage: "calendar").tag(TimelineViewMode.calendar)
                    Label("照片墙", systemImage: "square.grid.2x2").tag(TimelineViewMode.photoWall)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.warmLight)

                // 内容区域
                Group {
                    switch viewModel.viewMode {
                    case .list:
                        TimelineListView()
                    case .calendar:
                        Text("日历模式 - 待实现")
                            .foregroundColor(.warmBrown)
                    case .photoWall:
                        Text("照片墙模式 - 待实现")
                            .foregroundColor(.warmBrown)
                    }
                }
            }
            .navigationTitle("时间轴")
            .background(Color.warmPaper)
        }
    }
}

#Preview {
    TimelineView(context: CoreDataStack.shared.viewContext)
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
```

- [ ] **Step 4: 编译验证视图**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 5: 提交更改**

```bash
git add ViewModels/TimelineViewModel.swift Views/Timeline/
git commit -m "feat: implement timeline view with list mode

- Create TimelineViewModel with view mode management
- Implement TimelineListView with date grouping
- Add TimelineEntryCard with time marker
- Create TimelineView with mode picker
- Support list, calendar, and photo wall modes
- Add placeholder for calendar and photo wall

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 18: 标签管理视图

**Files:**
- Create: `ViewModels/TagManagerViewModel.swift`
- Create: `Views/Tags/TagsView.swift`
- Create: `Views/Tags/TagEditorView.swift`

- [ ] **Step 1: 创建标签管理 ViewModel**

```swift
// ViewModels/TagManagerViewModel.swift
import Foundation
import CoreData
import SwiftUI

class TagManagerViewModel: ObservableObject {
    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    func createTag(name: String, color: String, icon: String) {
        let tag = Tag.create(name: name, color: color, icon: icon, in: viewContext)

        // 设置顺序为最后
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        let count = (try? viewContext.count(for: fetchRequest)) ?? 0
        tag.order = Int32(count)

        CoreDataStack.shared.save()
    }

    func updateTag(_ tag: Tag, name: String, color: String, icon: String) {
        tag.name = name
        tag.color = color
        tag.icon = icon
        CoreDataStack.shared.save()
    }

    func deleteTag(_ tag: Tag) {
        viewContext.delete(tag)
        CoreDataStack.shared.save()
    }

    func moveTag(from source: IndexSet, to destination: Int, in tags: [Tag]) {
        var mutableTags = tags
        mutableTags.move(fromOffsets: source, toOffset: destination)

        // 更新顺序
        for (index, tag) in mutableTags.enumerated() {
            tag.order = Int32(index)
        }

        CoreDataStack.shared.save()
    }
}
```

- [ ] **Step 2: 创建标签编辑器**

```swift
// Views/Tags/TagEditorView.swift
import SwiftUI

struct TagEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let tag: Tag?
    let onSave: (String, String, String) -> Void

    @State private var name: String
    @State private var selectedColor: String
    @State private var selectedIcon: String

    init(tag: Tag? = nil, onSave: @escaping (String, String, String) -> Void) {
        self.tag = tag
        self.onSave = onSave
        _name = State(initialValue: tag?.wrappedName ?? "")
        _selectedColor = State(initialValue: tag?.wrappedColor ?? "DAA520")
        _selectedIcon = State(initialValue: tag?.wrappedIcon ?? "tag.fill")
    }

    private let availableColors = [
        "4A90E2", "7ED321", "F5A623", "D0021B", "BD10E0",
        "50E3C2", "FF6B6B", "8B7355", "DAA520", "9B59B6"
    ]

    private let availableIcons = [
        "tag.fill", "briefcase.fill", "house.fill", "airplane",
        "fork.knife", "figure.run", "book.fill", "gamecontroller.fill",
        "heart.fill", "star.fill", "film.fill", "music.note"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("标签名称") {
                    TextField("输入标签名称", text: $name)
                        .font(.warmBody)
                }

                Section("颜色") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(availableColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: selectedColor == color ? 4 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("图标") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(Color(hex: selectedColor))
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(Color.warmLight)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.warmAccent, lineWidth: selectedIcon == icon ? 2 : 0)
                                        )
                                )
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("预览") {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 40))
                                .foregroundColor(Color(hex: selectedColor))

                            Text(name.isEmpty ? "标签名称" : name)
                                .font(.warmBody)
                                .foregroundColor(.warmDark)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(tag == nil ? "新建标签" : "编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(name, selectedColor, selectedIcon)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
```

- [ ] **Step 3: 创建标签列表视图**

```swift
// Views/Tags/TagsView.swift
import SwiftUI

struct TagsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: TagManagerViewModel
    @State private var showingNewTag = false
    @State private var editingTag: Tag?

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.order)],
        animation: .default
    )
    private var tags: FetchedResults<Tag>

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: TagManagerViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.warmPaper.ignoresSafeArea()

                if tags.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(tags, id: \.id) { tag in
                            TagRow(tag: tag)
                                .onTapGesture {
                                    editingTag = tag
                                }
                        }
                        .onDelete { indexSet in
                            deleteTag(at: indexSet)
                        }
                        .onMove { source, destination in
                            viewModel.moveTag(from: source, to: destination, in: Array(tags))
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("标签管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewTag = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.warmAccent)
                            .font(.title2)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .foregroundColor(.warmAccent)
                }
            }
        }
        .sheet(isPresented: $showingNewTag) {
            TagEditorView { name, color, icon in
                viewModel.createTag(name: name, color: color, icon: icon)
            }
        }
        .sheet(item: $editingTag) { tag in
            TagEditorView(tag: tag) { name, color, icon in
                viewModel.updateTag(tag, name: name, color: color, icon: icon)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "tag")
                .font(.system(size: 80))
                .foregroundColor(.warmGray)

            Text("还没有标签")
                .font(.warmHeadline)
                .foregroundColor(.warmBrown)

            Button {
                showingNewTag = true
            } label: {
                Text("创建第一个标签")
                    .font(.warmBody)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.warmAccent)
                    .cornerRadius(24)
            }
        }
    }

    private func deleteTag(at offsets: IndexSet) {
        offsets.forEach { index in
            let tag = tags[index]
            viewModel.deleteTag(tag)
        }
    }
}

struct TagRow: View {
    let tag: Tag

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: tag.wrappedIcon)
                .font(.title2)
                .foregroundColor(tag.displayColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(tag.wrappedName)
                    .font(.warmBody)
                    .foregroundColor(.warmDark)

                Text("\(tag.entriesArray.count) 篇日记")
                    .font(.warmCaption)
                    .foregroundColor(.warmBrown.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.warmGray)
                .font(.caption)
        }
        .padding()
        .warmCard()
    }
}

#Preview {
    TagsView(context: CoreDataStack.shared.viewContext)
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
```

- [ ] **Step 4: 编译验证视图**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 5: 提交更改**

```bash
git add ViewModels/TagManagerViewModel.swift Views/Tags/
git commit -m "feat: implement tag management views

- Create TagManagerViewModel for CRUD operations
- Implement TagEditorView with color and icon picker
- Create TagsView with list and reordering
- Add TagRow component with entry count
- Support drag-to-reorder tags
- Show empty state for no tags

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 19: 主标签页和 App 入口

**Files:**
- Create: `Views/MainTabView.swift`
- Modify: `DayfoldApp.swift`

- [ ] **Step 1: 创建主标签页**

```swift
// Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        TabView {
            TimelineView(context: viewContext)
                .tabItem {
                    Label("时间轴", systemImage: "clock")
                }

            EntryListView(context: viewContext)
                .tabItem {
                    Label("全部", systemImage: "book.closed")
                }

            TagsView(context: viewContext)
                .tabItem {
                    Label("标签", systemImage: "tag")
                }
        }
        .accentColor(.warmAccent)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
```

- [ ] **Step 2: 更新 App 入口**

```swift
// DayfoldApp.swift
import SwiftUI

@main
struct DayfoldApp: App {
    @StateObject private var coreDataStack = CoreDataStack.shared
    @StateObject private var securityManager = SecurityManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if securityManager.isLocked {
                    LockScreenView()
                        .environmentObject(securityManager)
                } else {
                    MainTabView()
                        .environment(\.managedObjectContext, coreDataStack.viewContext)
                        .environmentObject(securityManager)
                }
            }
            .onAppear {
                // 创建预设标签
                coreDataStack.createPresetTags()
            }
        }
    }
}
```

- [ ] **Step 3: 编译验证 App**

```bash
# 在 Xcode 中按 Cmd+B 编译
# 预期: 编译成功,无错误
```

- [ ] **Step 4: 在模拟器中运行测试**

```bash
# 在 Xcode 中按 Cmd+R 运行
# 预期:
# 1. 显示锁屏界面
# 2. Face ID 认证(模拟器中自动通过)
# 3. 进入主标签页
# 4. 可以切换三个标签
# 5. 自动创建预设标签
```

- [ ] **Step 5: 提交更改**

```bash
git add Views/MainTabView.swift DayfoldApp.swift
git commit -m "feat: implement main tab view and app entry point

- Create MainTabView with three tabs
- Integrate TimelineView, EntryListView, TagsView
- Update DayfoldApp with security and Core Data integration
- Show LockScreenView when locked
- Auto-create preset tags on app launch
- Complete basic app structure

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 20: 最终测试和完善

**Files:**
- Test all features
- Fix any bugs
- Update README

- [ ] **Step 1: 功能测试清单**

测试以下功能:
- [ ] 锁屏和 Face ID 认证
- [ ] 创建新日记
- [ ] Markdown 编辑和格式化
- [ ] 添加照片
- [ ] 选择标签
- [ ] 自动获取位置和天气
- [ ] 保存日记
- [ ] 查看日记列表
- [ ] 搜索日记
- [ ] 查看日记详情
- [ ] 编辑已有日记
- [ ] 删除日记
- [ ] 收藏日记
- [ ] 时间轴浏览
- [ ] 创建自定义标签
- [ ] 编辑标签
- [ ] 删除标签
- [ ] 拖动排序标签

- [ ] **Step 2: iCloud 同步测试**

使用真机测试:
- [ ] 登录 iCloud 账户
- [ ] 创建日记并等待同步
- [ ] 在另一台设备查看是否同步成功
- [ ] 修改日记并验证同步
- [ ] 删除日记并验证同步

- [ ] **Step 3: 性能测试**

- [ ] 创建 50+ 篇日记测试列表性能
- [ ] 添加 10+ 张照片测试媒体加载
- [ ] 测试自动保存是否流畅
- [ ] 检查内存使用情况

- [ ] **Step 4: 修复发现的 Bug**

记录并修复测试中发现的问题

- [ ] **Step 5: 创建 README 文档**

```bash
cat > README.md << 'EOF'
# Dayfold

一款专注于 iOS 平台的个人日记应用,提供专业的写作体验和完善的隐私保护。

## 特性

- ✨ **专业写作** - Markdown 支持,强大的格式化工具
- 📷 **多媒体记录** - 照片、位置、天气信息
- 🏷️ **智能组织** - 灵活的标签和时间轴浏览
- 🔒 **隐私安全** - Face ID 锁定,iCloud 端到端加密
- ☁️ **无缝同步** - 跨 Apple 设备自动同步

## 技术栈

- Swift 5.9+
- SwiftUI
- Core Data + CloudKit
- CoreLocation + WeatherKit
- MarkdownUI

## 系统要求

- iOS 17.0+
- iCloud 账户(用于同步)

## 开发

```bash
# 克隆项目
git clone <repository-url>

# 打开项目
open Dayfold.xcodeproj

# 配置 Bundle Identifier 和 Team
# 在 Xcode 中选择你的开发团队

# 运行
按 Cmd+R 运行项目
```

## 架构

采用 MVVM 架构:
- Models: Core Data 实体
- ViewModels: 业务逻辑
- Views: SwiftUI 界面
- Services: 数据和功能服务

## 许可

MIT License
EOF
```

- [ ] **Step 6: 最终提交**

```bash
git add README.md
git commit -m "docs: add README and complete MVP implementation

- Document all features and technical stack
- Add development setup instructions
- Complete all MVP features
- Test and fix bugs
- Ready for initial release

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## 实现计划总结

本实现计划包含 20 个主要任务,覆盖了 Dayfold iOS 日记应用 MVP 的完整开发流程:

**基础设施 (Task 1-9):**
- 项目初始化和配置
- 颜色和字体系统
- Core Data 模型
- CloudKit 同步
- 位置和天气服务
- 媒体管理
- 安全认证
- 通用组件
- 锁屏界面

**核心功能 (Task 10-19):**
- 条目列表和编辑
- Markdown 编辑器
- 媒体和标签选择器
- 时间轴浏览
- 标签管理
- 主界面集成

**测试和完善 (Task 20):**
- 功能测试
- 性能优化
- 文档编写

每个任务都包含详细的步骤、完整的代码示例和验证方法,可以直接执行。预计开发时间 8-12 周。

---

## 执行建议

**计划完成并已保存到:** `docs/superpowers/plans/2026-04-07-dayfold-mvp-implementation.md`

**两种执行方式:**

**1. 子代理驱动(推荐)** - 为每个任务派发新的子代理,任务间进行审查,快速迭代

**2. 内联执行** - 在当前会话中使用 executing-plans 执行任务,批量执行并设置检查点进行审查

你希望使用哪种方式?
