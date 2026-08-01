// ViewModels/EntryEditorViewModel.swift
import Foundation
import CoreData
import CoreLocation
import UIKit
import Combine

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
    @Published var lastSaveError: Error?

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

    var isNewEntry: Bool {
        isNewEntryOnInit
    }

    var wordCount: Int {
        content.split(separator: " ").count
    }

    var readingTime: Int {
        max(1, wordCount / 200)
    }

    private struct EntrySnapshot {
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

    func save() async -> Bool {
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
        entryToSave.modifiedAt = Date()
        entryToSave.needsSync = true

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
            locationEntity.weatherTemperature = weather?.temperature ?? 0
            locationEntity.weatherCondition = weather?.condition
            locationEntity.weatherIcon = weather?.symbolName
            entryToSave.location = locationEntity
        }

        // 保存图片 (一对多关系)：仅当图片有增删时全量重建，避免编辑未动图片时误删
        if imagesChanged {
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

            // 还原图片:删除当前 MediaAsset 记录,按 snapshot 重建
            for asset in existing.mediaAssetsArray {
                viewContext.delete(asset)
            }
            for (index, filename) in snapshot.mediaFilenames.enumerated() {
                let asset = MediaAsset.create(type: .photo, filename: filename, in: viewContext)
                asset.order = Int32(index)
                asset.entry = existing
            }

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

    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                _ = await self.save()
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
