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

    private let viewContext: NSManagedObjectContext
    private var entry: Entry?
    private var autoSaveTimer: Timer?
    private let locationService = LocationService()
    private var cancellables = Set<AnyCancellable>()
    private let isNewEntryOnInit: Bool
    private let prefillDate: Date?
    private var isLoadingImages = false
    private var imagesChanged = false

    var isNewEntry: Bool {
        isNewEntryOnInit
    }

    var wordCount: Int {
        content.split(separator: " ").count
    }

    var readingTime: Int {
        max(1, wordCount / 200)
    }

    init(context: NSManagedObjectContext, entry: Entry? = nil, prefillDate: Date? = nil) {
        self.viewContext = context
        self.entry = entry
        self.isNewEntryOnInit = (entry == nil)
        self.prefillDate = prefillDate

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
            // 删除旧的 MediaAsset 记录与磁盘文件
            for asset in entryToSave.mediaAssetsArray {
                let filename = asset.wrappedFilename
                viewContext.delete(asset)
                Task { await MediaService.shared.deleteImage(filename: filename) }
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

        try? CoreDataStack.shared.save()

        isSaving = false
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
