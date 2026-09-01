// Services/PhotoLibraryService.swift
import Foundation
import Photos
import CoreLocation
import UIKit

/// 选图结果（照片库主路径 / PHPicker 兜底统一产物），由选择器回传给 EntryEditorViewModel
struct PickedPhoto: Identifiable {
    /// PHAsset.localIdentifier；PHPicker 兜底时为 "phpick-<uuid>"
    let id: String
    /// ≤ maxPickDimension 的解码图，编辑器展示与落盘共用
    let image: UIImage
    /// 拍摄时间；PHPicker 兜底路径通常为 nil
    let creationDate: Date?
    /// 拍摄坐标；PHPicker 兜底路径通常为 nil
    let coordinate: CLLocationCoordinate2D?
}

/// 照片库网格单元（轻量描述，不持有位图）
struct LibraryPhoto: Identifiable, Hashable {
    let id: String          // PHAsset.localIdentifier
    let asset: PHAsset

    var creationDate: Date? { asset.creationDate }
    var coordinate: CLLocationCoordinate2D? { asset.location?.coordinate }

    static func == (lhs: LibraryPhoto, rhs: LibraryPhoto) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 按拍摄日聚合的分组（组头「2026年9月1日 星期二」+ 时间范围「15:52–17:59」）
struct PhotoDayGroup: Identifiable {
    let dayStart: Date
    let title: String
    let timeRange: String?
    /// 组内按拍摄时间倒序（新的在上）
    let photos: [LibraryPhoto]

    var id: Date { dayStart }
}

/// 照片库只读服务：授权、枚举分组、缩略图缓存、选图解码、反向地理编码。
/// 不碰 Core Data、不碰 Documents/Media 落盘（落盘仍走 MediaService）。
final class PhotoLibraryService: ObservableObject {
    /// 选图解码长边上限，防 4032px 原图内存爆炸
    static let maxPickDimension: CGFloat = 2048

    @Published private(set) var photos: [LibraryPhoto] = []

    private let imageManager = PHCachingImageManager()

    // MARK: - 授权

    func currentStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// 仅在 notDetermined 时发起请求；其余状态原样返回
    func requestAuthorizationIfNeeded() async -> PHAuthorizationStatus {
        let status = currentStatus()
        guard status == .notDetermined else { return status }
        return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    // MARK: - 枚举 + 分组

    /// 后台枚举照片库快照，回主线程填充 @Published photos 并返回结果
    @discardableResult
    func reload() async -> [LibraryPhoto] {
        let loaded: [LibraryPhoto] = await Task.detached(priority: .userInitiated) {
            Self.fetchAllPhotos()
        }.value
        await MainActor.run { photos = loaded }
        return loaded
    }

    /// 一次性快照枚举（选择器会话内不观察增量变更），线程安全可在任意队列调用
    private static func fetchAllPhotos() -> [LibraryPhoto] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d AND isHidden == NO",
            PHAssetMediaType.image.rawValue
        )
        options.wantsIncrementalChangeDetails = false

        let result = PHAsset.fetchAssets(with: .image, options: options)
        var loaded: [LibraryPhoto] = []
        loaded.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            loaded.append(LibraryPhoto(id: asset.localIdentifier, asset: asset))
        }
        return loaded
    }

    /// 按拍摄日分组：天间倒序、组内倒序；无拍摄时间的归入「未知日期」组置底
    static func groupByDay(_ photos: [LibraryPhoto], calendar: Calendar = .current) -> [PhotoDayGroup] {
        let dayFormatter: DateFormatter = {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "zh_CN")
            fmt.dateFormat = "yyyy年M月d日 EEEE"
            return fmt
        }()
        let timeFormatter: DateFormatter = {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "zh_CN")
            fmt.dateFormat = "HH:mm"
            return fmt
        }()

        let dated = photos.filter { $0.creationDate != nil }
        let undated = photos.filter { $0.creationDate == nil }

        var groups = Dictionary(grouping: dated) { calendar.startOfDay(for: $0.creationDate!) }
            .map { day, items -> PhotoDayGroup in
                let sorted = items.sorted { $0.creationDate! > $1.creationDate! }
                let times = sorted.compactMap { $0.creationDate }
                let earliest = times.min() ?? day
                let latest = times.max() ?? day
                let range: String
                if earliest == latest {
                    range = timeFormatter.string(from: earliest)
                } else {
                    range = "\(timeFormatter.string(from: latest))–\(timeFormatter.string(from: earliest))"
                }
                return PhotoDayGroup(
                    dayStart: day,
                    title: dayFormatter.string(from: day),
                    timeRange: range,
                    photos: sorted
                )
            }
            .sorted { $0.dayStart > $1.dayStart }

        if !undated.isEmpty {
            groups.append(PhotoDayGroup(dayStart: .distantPast, title: "未知日期", timeRange: nil, photos: undated))
        }
        return groups
    }

    // MARK: - 网格缩略图（回调式：opportunistic 会对同一请求回调两次，故不做 async 包装）

    func requestThumbnail(
        _ photo: LibraryPhoto,
        cellSize: CGSize,
        onImage: @escaping (UIImage) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale)

        return imageManager.requestImage(
            for: photo.asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            // opportunistic：先回调 degraded 低清再回调 final，后到覆盖先到即可
            guard let image = image else { return }
            onImage(image)
        }
    }

    func cancelThumbnail(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }

    /// 分组进入视口时的批量预缓存
    func preheat(_ group: PhotoDayGroup, cellSize: CGSize) {
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale)
        imageManager.startCachingImages(
            for: group.photos.map(\.asset),
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    func endPreheat(_ group: PhotoDayGroup, cellSize: CGSize) {
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale)
        imageManager.stopCachingImages(
            for: group.photos.map(\.asset),
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    // MARK: - 完成时的选图解码（此场景只回调一次，可安全 async 包装）

    /// 按 ids 顺序解码 ≤ maxPickDimension 的图，失效 asset 自动跳过
    func loadPickedPhotos(ids: [String]) async -> [PickedPhoto] {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assetsById: [String: PHAsset] = [:]
        fetchResult.enumerateObjects { asset, _, _ in
            assetsById[asset.localIdentifier] = asset
        }

        var picked: [PickedPhoto] = []
        for id in ids {
            guard let asset = assetsById[id] else { continue }
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            let scale = UIScreen.main.scale
            let targetSize = CGSize(
                width: Self.maxPickDimension * scale,
                height: Self.maxPickDimension * scale
            )

            let image: UIImage? = await withCheckedContinuation { continuation in
                var resumed = false
                self.imageManager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, info in
                    let degraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                    guard !degraded else { return }
                    if !resumed {
                        resumed = true
                        continuation.resume(returning: image)
                    }
                }
            }

            guard let image = image else { continue }
            picked.append(PickedPhoto(
                id: id,
                image: image,
                creationDate: asset.creationDate,
                coordinate: asset.location?.coordinate
            ))
        }
        return picked
    }

    // MARK: - 反向地理编码（任意坐标，与 LocationService 设备定位链路解耦）

    /// 输出格式对齐 LocationService：「city·area」/「city」/「area」，失败返回 nil。
    /// CLGeocoder 不可并发复用，每次新建实例。
    static func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try? await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks?.first else { return nil }

        let city = placemark.locality ?? ""
        let area = placemark.subLocality ?? ""
        if !city.isEmpty && !area.isEmpty {
            return "\(city)·\(area)"
        }
        if !city.isEmpty { return city }
        if !area.isEmpty { return area }
        return nil
    }
}
