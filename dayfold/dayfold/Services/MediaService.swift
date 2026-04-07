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
