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

    /// 反向地理编码缓存：按 "lat,lon"（6 位小数）作为 key，避免对同一坐标重复打 Apple 服务器。
    /// 内存级缓存，进程重启清空；YAGNI 不做磁盘持久化。
    /// **仅缓存成功结果**，nil/超时/失败不缓存，避免弱网下一次失败永久污染。
    private static var placeNameCache: [String: String] = [:]
    private static let cacheQueue = DispatchQueue(label: "PhotoLibraryService.placeNameCache")
    /// 单次请求硬超时（CLGeocoder 弱网下可达 10+ 秒，这里 3s 兜底）
    private static let requestTimeout: TimeInterval = 3

    /// 输出格式对齐 LocationService：「city·area」/「city」/「area」，失败返回 nil。
    /// 行为：
    /// 1. 内存缓存命中 → 直接返回
    /// 2. 新建 CLGeocoder（不可并发复用）调 `reverseGeocodeLocation`
    /// 3. 3s 硬超时：超时分支直接 `return nil`，外层不等 CLGeocoder 内部网络
    ///    （注：CLGeocoder 不响应 Swift Concurrency cancellation，其内部网络请求会继续，
    ///     但回调结果被丢弃，整体函数保证 3s 内返回）
    /// 4. 成功结果才缓存；nil / 超时 / 失败均不缓存
    static func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let key = cacheKey(for: coordinate)

        // 1. 查缓存
        if let cached = cacheQueue.sync(execute: { placeNameCache[key] }) {
            return cached
        }

        // 2. 调 Apple Geo 服务 + 3s 超时
        let result = await resolveWithTimeout(coordinate)

        // 3. 仅成功结果写缓存（nil 不缓存）
        if let result {
            cacheQueue.sync {
                placeNameCache[key] = result
            }
        }
        return result
    }

    private static func cacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        // 6 位小数精度 ≈ 0.11 米，足以区分拍摄点；超过此精度的请求走同一缓存槽
        String(format: "%.6f,%.6f", coordinate.latitude, coordinate.longitude)
    }

    /// 调 `CLGeocoder.reverseGeocodeLocation` 并加 3s 硬超时。
    /// 用 `withTaskGroup` 跑"主请求"和"超时"两个子任务；**先返回的那个赢**。
    /// CLGeocoder 不响应 cancellation，超时后其回调被丢弃但内部网络继续；
    /// 外层 `placeName` 函数保证 3s 内 return，不阻塞调用方 UI。
    private static func resolveWithTimeout(_ coordinate: CLLocationCoordinate2D) async -> String? {
        await withTaskGroup(of: String?.self, returning: String?.self) { group in
            // 子任务 1：调 CLGeocoder（可能跑很久）
            group.addTask {
                await resolveDirectly(coordinate)
            }
            // 子任务 2：3s 后强制返回 nil（抢占 TaskGroup 完成）
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(requestTimeout * 1_000_000_000))
                return nil
            }
            // 第一个完成的子任务结果；cancel 剩余任务
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// 真正调 CLGeocoder。CLGeocoder 自身不可取消，但函数被外层超时抢占后，
    /// 此 task 仍可能在后台跑直到 CLGeocoder 内部超时——结果被丢弃，不影响 UI。
    private static func resolveDirectly(_ coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return format(placemark: placemarks.first)
        } catch {
            return nil
        }
    }

    private static func format(placemark: CLPlacemark?) -> String? {
        guard let placemark = placemark else { return nil }
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
