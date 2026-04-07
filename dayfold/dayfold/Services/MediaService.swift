// Services/MediaService.swift
import Foundation
import UIKit
import Photos

class MediaService {
    static let shared = MediaService()

    private let fileManager = FileManager.default
    private let fileQueue = DispatchQueue(label: "com.dayfold.mediaservice", qos: .userInitiated)

    private(set) lazy var mediaDirectory: URL = {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaURL = documentsURL.appendingPathComponent("Media", isDirectory: true)

        // 确保目录存在
        try? fileManager.createDirectory(at: mediaURL, withIntermediateDirectories: true)

        return mediaURL
    }()

    private init() {}

    func saveImage(_ image: UIImage) async -> (filename: String, thumbnail: Data?)? {
        return await withCheckedContinuation { continuation in
            fileQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                let filename = "\(UUID().uuidString).jpg"
                let fileURL = self.mediaDirectory.appendingPathComponent(filename)

                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    try imageData.write(to: fileURL)
                    let thumbnail = self.generateThumbnail(from: image)
                    continuation.resume(returning: (filename, thumbnail))
                } catch {
                    print("Failed to save image: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func loadImage(filename: String) async -> UIImage? {
        // Validate filename to prevent path traversal
        guard isValidFilename(filename) else {
            print("Invalid filename: \(filename)")
            return nil
        }

        return await withCheckedContinuation { continuation in
            fileQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                let fileURL = self.mediaDirectory.appendingPathComponent(filename)
                guard let imageData = try? Data(contentsOf: fileURL) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(data: imageData))
            }
        }
    }

    @discardableResult
    func deleteImage(filename: String) async -> Bool {
        // Validate filename to prevent path traversal
        guard isValidFilename(filename) else {
            print("Invalid filename: \(filename)")
            return false
        }

        return await withCheckedContinuation { continuation in
            fileQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                let fileURL = self.mediaDirectory.appendingPathComponent(filename)
                do {
                    try self.fileManager.removeItem(at: fileURL)
                    continuation.resume(returning: true)
                } catch {
                    print("Failed to delete image: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private func isValidFilename(_ filename: String) -> Bool {
        // Prevent path traversal attacks
        let invalidCharacters = CharacterSet(charactersIn: "../\\:")
        return !filename.isEmpty && filename.rangeOfCharacter(from: invalidCharacters) == nil
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
