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
    @Published var images: [UIImage] = [] {
        didSet {
            if !isLoadingImages { imagesChanged = true }
        }
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

    // 编辑已有日记时，将已保存的图片按顺序加载到 images 供编辑器展示
    private func loadExistingImages(from entry: Entry) {
        let filenames = entry.mediaAssetsArray.map { $0.wrappedFilename }
        Task { [weak self] in
            var loaded: [UIImage] = []
            for filename in filenames {
                if let image = await MediaService.shared.loadImage(filename: filename) {
                    loaded.append(image)
                }
            }
            await MainActor.run {
                guard let self = self else { return }
                // 若用户在加载完成前已改动图片，不覆盖其操作结果
                guard !self.imagesChanged else { return }
                self.isLoadingImages = true
                self.images = loaded
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
        // 用户确认采纳照片拍摄时间时覆盖 createdAt（新建/编辑统一，idempotent，auto-save 亦同步）
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
            // 位置可能来自照片元数据（无天气数据），weather 为空时保留实体原值，避免清零
            if let weather = weather {
                locationEntity.weatherTemperature = weather.temperature
                locationEntity.weatherCondition = weather.condition
                locationEntity.weatherIcon = weather.symbolName
            }
            entryToSave.location = locationEntity
        }

        // 保存图片 (一对多关系)：仅在「完成」路径且图片有增删时全量重建。
        // auto-save 跳过图片处理，避免在用户尚未决定完成/取消时就物理删除原图（防数据丢失）。
        if !isAutoSave && imagesChanged {
            // 延迟删除:仅记录旧文件名,真正删除推迟到 save() 成功之后
            let oldFilenames = entryToSave.mediaAssetsArray.map { $0.wrappedFilename }
            deferredOldFilenames.append(contentsOf: oldFilenames)

            // 删除旧 MediaAsset 记录(关系自动解绑),不删磁盘文件
            for asset in entryToSave.mediaAssetsArray {
                viewContext.delete(asset)
            }
            // 按当前 images 顺序重新保存
            for (index, image) in images.enumerated() {
                if let result = await MediaService.shared.saveImage(image) {
                    let asset = MediaAsset.create(type: .photo, filename: result.filename, in: viewContext)
                    asset.thumbnailData = result.thumbnail
                    asset.order = Int32(index)
                    asset.width = Int32(image.size.width)
                    asset.height = Int32(image.size.height)
                    asset.entry = entryToSave
                }
            }
            imagesChanged = false
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

        // 取消编辑:把 current VM 状态回滚到 snapshot 前的字段
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

            // 还原 location/weather 字段
            if let location = existing.location {
                location.placeName = snapshot.placeName
                location.weatherTemperature = snapshot.weatherTemperature
                location.weatherCondition = snapshot.weatherCondition.isEmpty ? nil : snapshot.weatherCondition
                location.weatherIcon = snapshot.weatherIcon
            }

            // 图片无需回滚:auto-save 不参与图片重建,编辑期间数据库 MediaAsset 始终为原始集合,
            // 用户内存中的图片改动(imagesChanged)从未落盘,取消即自然丢弃。

            // 取消时不删 deferred 旧图(用户没点完成)
            deferredOldFilenames.removeAll()

            try? CoreDataStack.shared.save()
            return
        }

        // 新建日记:entry 已 auto-save 创建 → 物理删除(不进回收站)
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

    func addImage(_ image: UIImage) {
        images.append(image)
    }

    func removeImage(at index: Int) {
        guard index < images.count else { return }
        images.remove(at: index)
    }

    /// 选择器回传：一次性追加，didSet 置脏 imagesChanged（单次 diff）；
    /// 同时取带拍摄元数据照片中最早者为 anchor，弹出「使用附件时间和位置？」确认。
    /// 连续多批选图时与旧 pending 合并：时间取更早者，坐标/地名保留旧值（可能仍在解析中）。
    func addPickedPhotos(_ photos: [PickedPhoto]) {
        guard !photos.isEmpty else { return }
        images.append(contentsOf: photos.map(\.image))

        guard let anchor = photos
            .compactMap({ photo -> (date: Date, coordinate: CLLocationCoordinate2D?)? in
                guard let date = photo.creationDate else { return nil }
                return (date, photo.coordinate)
            })
            .min(by: { $0.date < $1.date })
        else { return }

        if let existing = pendingMetadata, let existingDate = existing.createdAt,
           existingDate <= anchor.date {
            return  // 已有待确认的更早 anchor，保持不变
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

    /// 弹窗「是，使用」：日记时间改用照片拍摄时间，位置/地名改用照片坐标
    func confirmApplyPhotoMetadata() {
        guard let meta = pendingMetadata else { return }
        attachedCreatedAt = meta.createdAt
        if let coordinate = meta.coordinate {
            location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            placeName = meta.placeName
        }
        pendingMetadata = nil
        // 地名仍在解析时，让在途请求完成后补写 placeName（见 resolvePhotoPlaceName）
    }

    /// 弹窗「否，保持不变」：丢弃待确认元数据
    func declineApplyPhotoMetadata() {
        pendingMetadata = nil
        placeResolveGeneration += 1  // 作废在途地名解析
    }

    /// 照片坐标反向地理编码，结果写回 pendingMetadata；弹窗已确认则补写 placeName
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

    /// 编辑器顶部展示用的条目日期：优先用户确认的照片时间，其次已存日期/预填日期
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
