// Views/Entry/Components/PhotoLibraryPickerView.swift
import SwiftUI
import Photos
import PhotosUI

/// 全屏深色照片库选择器（Day One 风格）：
/// 按拍摄日期分组的多选网格，完成后一次性回传 [PickedPhoto]。
/// 只读照片库，不碰 Core Data —— fullScreenCover 呈现时无需注入 managedObjectContext。
struct PhotoLibraryPickerView: View {
    /// 点「完成」后回传（保序）；空选或取消不回调
    let onDone: ([PickedPhoto]) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = PhotoLibraryService()

    @State private var status: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var groups: [PhotoDayGroup] = []
    @State private var selectedIDs: [String] = []
    @State private var selectedSet: Set<String> = []
    @State private var cellSide: CGFloat = max(60, (UIScreen.main.bounds.width - 4) / 3)
    @State private var showingSystemPicker = false
    @State private var isFinishing = false

    private let pickerBackground = Color(hex: "232329")

    var body: some View {
        VStack(spacing: 0) {
            PickerTopBar(
                count: selectedIDs.count,
                isFinishing: isFinishing,
                onClose: { dismiss() },
                onDone: { Task { await finish() } }
            )
            .background(pickerBackground)

            switch status {
            case .authorized, .limited:
                if status == .limited {
                    limitedBanner
                }
                photoGrid
            case .notDetermined:
                // 系统授权弹窗会覆盖在空态之上，授权结果返回后重载
                loadingState
            case .denied, .restricted:
                PermissionDeniedView(
                    status: status,
                    onOpenSettings: status == .denied ? openSettings : nil,
                    onUseSystemPicker: status == .denied ? { showingSystemPicker = true } : nil
                )
            @unknown default:
                loadingState
            }
        }
        .background(pickerBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task { await initialLoad() }
        .sheet(isPresented: $showingSystemPicker) {
            PHPickerFallback { picked in
                showingSystemPicker = false
                guard !picked.isEmpty else { return }
                dismiss()
                onDone(picked)
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - 数据加载

    private func initialLoad() async {
        status = await service.requestAuthorizationIfNeeded()
        guard status == .authorized || status == .limited else { return }
        let all = await service.reload()
        groups = await Task.detached(priority: .userInitiated) {
            PhotoLibraryService.groupByDay(all)
        }.value
    }

    // MARK: - 网格

    private var photoGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if groups.isEmpty {
                    emptyState
                }
                ForEach(groups) { group in
                    Section {
                        LazyVGrid(columns: gridColumns, spacing: 2) {
                            ForEach(group.photos) { photo in
                                ThumbnailCell(
                                    photo: photo,
                                    side: cellSide,
                                    isSelected: selectedSet.contains(photo.id),
                                    order: selectedIDs.firstIndex(of: photo.id).map { $0 + 1 },
                                    service: service,
                                    onTap: { toggle(photo.id) }
                                )
                            }
                        }
                    } header: {
                        sectionHeader(group)
                    }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
            cellSide = max(60, (width - 4) / 3)
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    }

    private func sectionHeader(_ group: PhotoDayGroup) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(group.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            if let range = group.timeRange {
                Text(range)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(pickerBackground)
        .onAppear {
            service.preheat(group, cellSize: CGSize(width: cellSide, height: cellSide))
        }
        .onDisappear {
            service.endPreheat(group, cellSize: CGSize(width: cellSide, height: cellSide))
        }
    }

    private var loadingState: some View {
        ProgressView()
            .tint(.warmDark)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// limited 权限提示条：补选走系统 PHPicker（不依赖相册权限，可访问全部照片）
    private var limitedBanner: some View {
        HStack(spacing: 8) {
            Text("仅可访问部分照片")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Button {
                showingSystemPicker = true
            } label: {
                Text("选择更多照片")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.warmAccent))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.warmLight)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundColor(.warmBrown)
            Text("没有照片")
                .font(.system(size: 15))
                .foregroundColor(.warmBrown)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    // MARK: - 多选

    private func toggle(_ id: String) {
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
            selectedSet.remove(id)
        } else {
            selectedIDs.append(id)
            selectedSet.insert(id)
        }
    }

    /// 完成后先在 picker 内解码 ≤2048px 版本，避免回传后编辑器占位闪烁与原图内存爆炸
    private func finish() async {
        guard !selectedIDs.isEmpty, !isFinishing else { return }
        isFinishing = true
        let picked = await service.loadPickedPhotos(ids: selectedIDs)
        isFinishing = false
        guard !picked.isEmpty else { return }
        dismiss()
        onDone(picked)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - 顶部栏

private struct PickerTopBar: View {
    let count: Int
    let isFinishing: Bool
    let onClose: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }

            Spacer()

            // 「所有媒体」筛选占位（仅图片库，暂不做真实筛选）
            HStack(spacing: 4) {
                Text("所有媒体")
                    .font(.system(size: 16, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)

            Spacer()

            Button(action: onDone) {
                if isFinishing {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 64, height: 34)
                } else if count > 0 {
                    Text("完成(\(count))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Capsule().fill(Color.warmAccent))
                } else {
                    Text("完成")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
            }
            .disabled(count == 0 || isFinishing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - 网格单元格

private struct ThumbnailCell: View {
    let photo: LibraryPhoto
    let side: CGFloat
    let isSelected: Bool
    let order: Int?
    let service: PhotoLibraryService
    let onTap: () -> Void

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .overlay {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .frame(width: side, height: side)
                .clipped()

            if isSelected {
                Color.black.opacity(0.25)
                    .frame(width: side, height: side)
            }

            selectionBadge
                .padding(6)
        }
        .frame(width: side, height: side)
        .overlay(
            Rectangle()
                .stroke(isSelected ? Color.warmAccent : .clear, lineWidth: 1.5)
                .frame(width: side, height: side)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onAppear {
            guard image == nil else { return }
            requestID = service.requestThumbnail(
                photo,
                cellSize: CGSize(width: side, height: side)
            ) { img in
                image = img
            }
        }
        .onDisappear {
            if let id = requestID {
                service.cancelThumbnail(id)
                requestID = nil
            }
        }
    }

    private var selectionBadge: some View {
        Group {
            if let order = order {
                Text("\(order)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.warmAccent))
            } else {
                Circle()
                    .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.black.opacity(0.25)))
            }
        }
    }
}

// MARK: - 权限引导页

private struct PermissionDeniedView: View {
    let status: PHAuthorizationStatus
    let onOpenSettings: (() -> Void)?
    let onUseSystemPicker: (() -> Void)?

    private var title: String {
        status == .restricted ? "无法访问照片" : "未获得照片权限"
    }

    private var message: String {
        status == .restricted
            ? "照片访问受限（可能由家长控制或设备策略导致）。"
            : "请在系统设置中允许 Dayfold 访问照片，或使用系统相册选择器直接选图。"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundColor(.warmBrown)
                .padding(.top, 80)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.warmDark)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.warmBrown)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let onOpenSettings = onOpenSettings {
                Button(action: onOpenSettings) {
                    Text("前往设置")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.warmAccent))
                }
                .padding(.horizontal, 60)
            }

            if let onUseSystemPicker = onUseSystemPicker {
                Button(action: onUseSystemPicker) {
                    Text("从系统相册选择")
                        .font(.system(size: 15))
                        .foregroundColor(.warmAccent)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 系统 PHPicker 兜底（无需相册权限）

private struct PHPickerFallback: UIViewControllerRepresentable {
    let onPicked: ([PickedPhoto]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 10
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: ([PickedPhoto]) -> Void

        init(onPicked: @escaping ([PickedPhoto]) -> Void) {
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else {
                onPicked([])
                return
            }

            // 并发加载，完成后按选择顺序回传
            let group = DispatchGroup()
            let queue = DispatchQueue(label: "dayfold.phpicker.load")
            var pending: [Int: PickedPhoto] = [:]

            for (index, result) in results.enumerated() {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage else { return }
                    queue.async {
                        pending[index] = PickedPhoto(
                            id: result.assetIdentifier ?? "phpick-\(UUID().uuidString)",
                            image: image,
                            creationDate: nil,
                            coordinate: nil
                        )
                    }
                }
            }

            group.notify(queue: .main) { [onPicked] in
                let picked = results.indices.compactMap { pending[$0] }
                onPicked(picked)
            }
        }
    }
}
