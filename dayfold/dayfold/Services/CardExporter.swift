// Services/CardExporter.swift
import SwiftUI
import Photos

@MainActor
struct CardExporter {
    /// 将 SwiftUI 视图渲染为 UIImage（scale 3x，适合分享）
    static func render<V: View>(_ view: V) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    /// 保存图片到系统相册，返回是否成功
    static func saveToPhotos(_ image: UIImage) async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    continuation.resume(returning: false)
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, _ in
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
