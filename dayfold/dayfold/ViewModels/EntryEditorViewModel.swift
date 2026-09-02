// ViewModels/EntryEditorViewModel.swift
import Foundation
import CoreData
import CoreLocation
import UIKit
import Combine

/// 「使用附件时间和位置？」弹窗的数据源：anchor 照片的拍摄时间与坐标
struct PendingPhotoMetadata {
    let createdAt: Date?
    let coordinate: CLLocationCoordinate2D?
    var placeName: String?
    var isResolvingPlace: Bool
}

@MainActor
class EntryEditorViewModel: ObservableObject {
    @Published var title = ""
    @Published var content = ""
    @Published var selectedTags: [Tag] = []
    /// 内存中用于渲染内联富文本的图片字典 [filename: UIImage]
    @Published var imagesMap: [String: UIImage] = [:] {
        didSet {
            if !isLoadingImages { imagesChanged = true }
        }
    }
    /// 兼容已有逻辑的图片数组计算属性
    var images: [UIImage] {
        Array(imagesMap.values)
    }

    @Published var location: CLLocation?
    @Published var placeName: String?
    @Published var weather: WeatherData?
    @Published var isSaving = false
    @Published var isFavorite = false
    @Published var mood: String = ""
    @Published var lastSaveError: Error?
    /// 待确认的照片元数据；非 nil 时编辑器弹出「使用附件时间和位置？」
    @Published var pendingMetadata: PendingPhotoMetadata?
    /// 用户确认采纳的照片拍摄时间（保存时写入 entry.createdAt）
    @Published private(set) var attachedCreatedAt: Date?

    private let viewContext: NSManagedObjectContext
    private var entry: Entry?
    private var autoSaveTimer: Timer?
    private let locationService = LocationService()
    private var cancellables = Set<AnyCancellable>()
    private let isNewEntryOnInit: Bool
    private let prefillDate: Date?
    private let notebook: Notebook?
    private var isLoadingImages = false
    private var imagesChanged = false
    private var originalSnapshot: EntrySnapshot?
    private var deferredOldFilenames: [String] = []
    /// 照片地名解析代际：pending 被替换/清除时递增，使在途请求结果作废
    private var placeResolveGeneration = 0
    /// 图片持久化在途任务集合：save() 入口等待全部完成，避免 temp filename 漏写
    private var pendingSaveTasks: [Task<Void, Never>] = []

    var isNewEntry: Bool {
        isNewEntryOnInit
    }

    /// 编辑器顶部展示用的笔记本名;新建时若已指定 notebook 则显示其名,否则显示「默认」
    var notebookDisplayName: String {
        notebook?.wrappedName ?? "默认"
    }

    var wordCount: Int {
        // 中文 / 日文 / 韩文字符按字计,英文 / 数字按空格分词后求和
        var count = 0
        var latinBuffer = ""
        for scalar in content.unicodeScalars {
            if scalar == " " {
                if !latinBuffer.isEmpty { count += 1; latinBuffer = "" }
            } else if CharacterSet.alphanumerics.contains(scalar) {
                latinBuffer.unicodeScalars.append(scalar)
            } else {
                if !latinBuffer.isEmpty { count += 1; latinBuffer = "" }
                count += 1
            }
        }
        if !latinBuffer.isEmpty { count += 1 }
        return count
    }

    var readingTime: Int {
        max(1, wordCount / 200)
    }

    private struct EntrySnapshot {
        var createdAt: Date
        var title: String
        var content: String
        var mood: String
        var isFavorite: Bool
        var tags: [Tag]
        var mediaFilenames: [String]
        var placeName: String?
        var weatherTemperature: Double
        var weatherCondition: String
        var weatherIcon: String

        static func capture(from entry: Entry, selectedTags: [Tag]) -> EntrySnapshot {
            EntrySnapshot(
                createdAt: entry.createdAt ?? Date(),
                title: entry.wrappedTitle,
                content: entry.wrappedContent,
                mood: entry.wrappedMood,
                isFavorite: entry.isFavorite,
                tags: selectedTags,
                mediaFilenames: entry.mediaAssetsArray.map { $0.wrappedFilename },
                placeName: entry.location?.wrappedPlaceName,
                weatherTemperature: entry.location?.weatherTemperature ?? 0,
                weatherCondition: entry.location?.weatherCondition ?? "",
                weatherIcon: entry.location?.weatherIcon ?? "sun.max.fill"
            )
        }
    }

    init(context: NSManagedObjectContext, entry: Entry? = nil, prefillDate: Date? = nil, notebook: Notebook? = nil) {
        self.viewContext = context
        self.entry = entry
        self.isNewEntryOnInit = (entry == nil)
        self.prefillDate = prefillDate
        self.notebook = notebook

        if let entry = entry {
            self.title = entry.wrappedTitle
            self.content = entry.wrappedContent
            self.selectedTags = entry.tagsArray
            self.isFavorite = entry.isFavorite
            self.mood = entry.wrappedMood
            self.location = entry.location?.coordinate.toLocation()
            self.placeName = entry.location?.wrappedPlaceName

            if let location = entry.location {
                self.weather = WeatherData(
                    temperature: location.weatherTemperature,
                    condition: location.weatherCondition ?? "",
                    symbolName: location.weatherIcon ?? "sun.max.fill"
                )
            }

            loadExistingImages(from: entry)
            self.originalSnapshot = EntrySnapshot.capture(from: entry, selectedTags: entry.tagsArray)
        } else {
            fetchLocationAndWeather()
        }

        startAutoSave()
    }

    // 编辑已有日记时，从正文的 ![](filename) 标记加载图片到 imagesMap 供编辑器展示。
    // 优先按 content 解析（图文混排后图片位置以正文为准），fallback 才用 MediaAsset。
    private func loadExistingImages(from entry: Entry) {
        let markdown = entry.wrappedContent
        let assetFilenames = entry.mediaAssetsArray.map { $0.wrappedFilename }
        Task { [weak self] in
            var map: [String: UIImage] = [:]
            var seen: Set<String> = []

            // 1) 从正文解析的图片标记优先（图文混排权威位置）
            let regex = try? NSRegularExpression(pattern: #"!\[(.*?)\]\((.*?)\)"#, options: [])
            let nsMarkdown = markdown as NSString
            let matches = regex?.matches(in: markdown, options: [], range: NSRange(location: 0, length: nsMarkdown.length)) ?? []
            for match in matches {
                let filename = nsMarkdown.substring(with: match.range(at: 2))
                guard !seen.contains(filename) else { continue }
                seen.insert(filename)
                if let image = await MediaService.shared.loadImage(filename: filename) {
                    map[filename] = image
                }
            }

            // 2) fallback：MediaAsset 中存在但正文没有的图（旧数据兼容）
            for filename in assetFilenames where !seen.contains(filename) {
                if let image = await MediaService.shared.loadImage(filename: filename) {
                    map[filename] = image
                    // 自动追加到文末
                    await MainActor.run {
                        guard let self = self else { return }
                        guard !self.imagesChanged else { return }
                        let tag = "![](\(filename))"
                        if !self.content.contains(tag) {
                            if !self.content.isEmpty && !self.content.hasSuffix("\n") {
                                self.content += "\n"
                            }
                            self.content += "\(tag)\n"
                        }
                    }
                }
            }

            await MainActor.run {
                guard let self = self else { return }
                guard !self.imagesChanged else { return }
                self.isLoadingImages = true
                self.imagesMap = map
                self.isLoadingImages = false
            }
        }
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    func save(isAutoSave: Bool = false) async -> Bool {
        // 标题与正文都为空时不保存
        guard !title.isEmpty || !content.isEmpty else { return false }

        // 先 await 在途的图片持久化任务，避免 race 导致正文写入 temp UUID
        if !pendingSaveTasks.isEmpty {
            let tasks = pendingSaveTasks
            pendingSaveTasks.removeAll()
            for task in tasks { await task.value }
        }

        isSaving = true

        let entryToSave: Entry
        if let existing = entry {
            entryToSave = existing
        } else {
            entryToSave = Entry.create(in: viewContext)
            if let prefillDate = prefillDate {
                entryToSave.createdAt = prefillDate
            }
            if let notebook = notebook {
                entryToSave.notebook = notebook
            }
            entry = entryToSave
        }

        entryToSave.title = title.isEmpty ? nil : title
        entryToSave.content = content
        entryToSave.isFavorite = isFavorite
        entryToSave.mood = mood.isEmpty ? nil : mood
        entryToSave.modifiedAt = Date()
        entryToSave.needsSync = true
        if let attachedDate = attachedCreatedAt {
            entryToSave.createdAt = attachedDate
        }

        // 保存标签 (多对多关系)
        entryToSave.tags = NSSet(array: selectedTags)

        // 保存位置和天气
        if let location = location {
            let locationEntity = entryToSave.location ?? Location.create(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                in: viewContext
            )
            locationEntity.placeName = placeName
            if let weather = weather {
                locationEntity.weatherTemperature = weather.temperature
                locationEntity.weatherCondition = weather.condition
                locationEntity.weatherIcon = weather.symbolName
            }
            entryToSave.location = locationEntity
        }

        // 保存图片 (一对多关系)：
        // - auto-save：仅增量补建缺失的 MediaAsset，不删除（避免回收进行中的图）。
        // - 完成路径（isAutoSave=false）：按正文顺序全量 reconcile，删除不在正文里的旧图。
        let imageRegex = try! NSRegularExpression(pattern: #"!\[(.*?)\]\((.*?)\)"#, options: [])
        let nsContent = content as NSString
        let matches = imageRegex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
        let presentFilenames = matches.map { nsContent.substring(with: $0.range(at: 2)) }
        let presentSet = Set(presentFilenames)
        let existingFilenames = Set(entryToSave.mediaAssetsArray.map { $0.wrappedFilename })

        if isAutoSave {
            // auto-save：补建缺失的 MediaAsset，更新已有 order
            for (index, filename) in presentFilenames.enumerated() {
                if let existing = entryToSave.mediaAssetsArray.first(where: { $0.wrappedFilename == filename }) {
                    existing.order = Int32(index)
                } else if let image = imagesMap[filename] {
                    let asset = MediaAsset.create(type: .photo, filename: filename, in: viewContext)
                    asset.order = Int32(index)
                    asset.width = Int32(image.size.width)
                    asset.height = Int32(image.size.height)
                    asset.thumbnailData = MediaService.shared.generateThumbnail(from: image)
                    asset.entry = entryToSave
                }
            }
        } else if imagesChanged {
            // 完成路径：删除旧 MediaAsset（不再出现在正文中的图片）
            for asset in entryToSave.mediaAssetsArray where !presentSet.contains(asset.wrappedFilename) {
                viewContext.delete(asset)
            }
            // 按正文出现顺序创建/同步 MediaAsset
            for (index, filename) in presentFilenames.enumerated() {
                if let existing = entryToSave.mediaAssetsArray.first(where: { $0.wrappedFilename == filename }) {
                    existing.order = Int32(index)
                } else if let image = imagesMap[filename] {
                    let asset = MediaAsset.create(type: .photo, filename: filename, in: viewContext)
                    asset.order = Int32(index)
                    asset.width = Int32(image.size.width)
                    asset.height = Int32(image.size.height)
                    asset.thumbnailData = MediaService.shared.generateThumbnail(from: image)
                    asset.entry = entryToSave
                }
            }
            imagesChanged = false
        }

        // 清理：imagesMap 里存在但 content 已经移除的图片，物理文件清理（仅完成路径）
        if !isAutoSave {
            let removed = imagesMap.keys.filter { !presentSet.contains($0) && existingFilenames.contains($0) }
            for filename in removed {
                Task { await MediaService.shared.deleteImage(filename: filename) }
            }
        }

        do {
            try CoreDataStack.shared.save()
        } catch {
            lastSaveError = error
            isSaving = false
            return false
        }

        // 保存成功后,真正物理删除被替换的旧图文件
        if !deferredOldFilenames.isEmpty {
            let toDelete = deferredOldFilenames
            deferredOldFilenames.removeAll()
            Task { await MediaService.shared.deleteImages(filenames: toDelete) }
        }

        isSaving = false
        return true
    }

    func cancel() async {
        autoSaveTimer?.invalidate()

        if let snapshot = originalSnapshot {
            guard let existing = entry else { return }
            existing.createdAt = snapshot.createdAt
            existing.title = snapshot.title.isEmpty ? nil : snapshot.title
            existing.content = snapshot.content
            existing.mood = snapshot.mood.isEmpty ? nil : snapshot.mood
            existing.isFavorite = snapshot.isFavorite
            existing.tags = NSSet(array: snapshot.tags)
            existing.modifiedAt = Date()
            existing.needsSync = true

            if let location = existing.location {
                location.placeName = snapshot.placeName
                location.weatherTemperature = snapshot.weatherTemperature
                location.weatherCondition = snapshot.weatherCondition.isEmpty ? nil : snapshot.weatherCondition
                location.weatherIcon = snapshot.weatherIcon
            }

            deferredOldFilenames.removeAll()
            try? CoreDataStack.shared.save()
            return
        }

        // 新建日记取消
        guard let draft = entry else { return }
        for asset in draft.mediaAssetsArray {
            let filename = asset.wrappedFilename
            viewContext.delete(asset)
            Task { await MediaService.shared.deleteImage(filename: filename) }
        }
        if let location = draft.location {
            viewContext.delete(location)
        }
        viewContext.delete(draft)
        deferredOldFilenames.removeAll()
        try? CoreDataStack.shared.save()
    }

    func addTag(_ tag: Tag) {
        if !selectedTags.contains(where: { $0.id == tag.id }) {
            selectedTags.append(tag)
        }
    }

    func removeTag(_ tag: Tag) {
        selectedTags.removeAll { $0.id == tag.id }
    }

    /// 选择器回传：先立即把每张图持久化到 MediaService 拿到真实 filename，
    /// 再把 `![](realFilename)` 插入正文，避免 auto-save 写入 temp UUID 后重开
    /// 编辑器找不到图片文件导致图片降级为 markdown 原文。
    func addPickedPhotos(_ photos: [PickedPhoto]) {
        guard !photos.isEmpty else { return }

        let task = Task { [weak self] in
            for photo in photos {
                guard let saved = await MediaService.shared.saveImage(photo.image) else { continue }
                let filename = saved.filename
                await MainActor.run {
                    guard let self = self else { return }
                    self.imagesMap[filename] = photo.image
                    let tag = "![](\(filename))"
                    if !self.content.isEmpty && !self.content.hasSuffix("\n") {
                        self.content += "\n"
                    }
                    self.content += "\(tag)\n"
                }
            }
        }
        pendingSaveTasks.append(task)

        // 元数据确认沿用 anchor（最早一张有 EXIF 的图）
        guard let anchor = photos
            .compactMap({ photo -> (date: Date, coordinate: CLLocationCoordinate2D?)? in
                guard let date = photo.creationDate else { return nil }
                return (date, photo.coordinate)
            })
            .min(by: { $0.date < $1.date })
        else { return }

        if let existing = pendingMetadata, let existingDate = existing.createdAt,
           existingDate <= anchor.date {
            return
        }

        pendingMetadata = PendingPhotoMetadata(
            createdAt: anchor.date,
            coordinate: pendingMetadata?.coordinate ?? anchor.coordinate,
            placeName: pendingMetadata?.placeName,
            isResolvingPlace: false
        )
        if let coordinate = pendingMetadata?.coordinate {
            resolvePhotoPlaceName(for: coordinate)
        }
    }

    func confirmApplyPhotoMetadata() {
        guard let meta = pendingMetadata else { return }
        attachedCreatedAt = meta.createdAt
        if let coordinate = meta.coordinate {
            location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            placeName = meta.placeName
        }
        pendingMetadata = nil
    }

    func declineApplyPhotoMetadata() {
        pendingMetadata = nil
        placeResolveGeneration += 1
    }

    private func resolvePhotoPlaceName(for coordinate: CLLocationCoordinate2D) {
        placeResolveGeneration += 1
        let generation = placeResolveGeneration
        pendingMetadata?.isResolvingPlace = true
        Task { [weak self] in
            let name = await PhotoLibraryService.placeName(for: coordinate)
            guard let self, self.placeResolveGeneration == generation else { return }
            if self.pendingMetadata != nil {
                self.pendingMetadata?.placeName = name
                self.pendingMetadata?.isResolvingPlace = false
            } else if self.attachedCreatedAt != nil {
                self.placeName = name
            }
        }
    }

    var effectiveDate: Date {
        attachedCreatedAt ?? entry?.createdAt ?? prefillDate ?? Date()
    }

    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                _ = await self.save(isAutoSave: true)
            }
        }
    }

    private func fetchLocationAndWeather() {
        locationService.requestLocation()

        locationService.$currentLocation
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.location = location
                self?.placeName = self?.locationService.placeName

                Task { [weak self] in
                    self?.weather = await WeatherService.shared.fetchWeatherIfPossible(for: location)
                }
            }
            .store(in: &cancellables)
    }
}

extension CLLocationCoordinate2D {
    func toLocation() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
