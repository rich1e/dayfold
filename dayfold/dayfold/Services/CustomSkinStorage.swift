// Services/CustomSkinStorage.swift
import Foundation
import UIKit

/// Custom Skin 文件存储。
///
/// 目录：`Documents/Skins/<notebookID>.jpg`
///
/// 约定：
/// - 文件名由调用方传入（一般固定为 `<notebookID>.jpg`，与 `Notebook.customSkinFilename` 保持一致）。
/// - 写入前必须先过 `ImageCropper.cropToCoverAspect` 裁剪为 12:17。
/// - JPEG 0.8，与 `MediaService` 的图片写入策略对齐。
///
/// 单例：与 `MediaService.shared` 同款，方便全局访问。
final class CustomSkinStorage {
    static let shared = CustomSkinStorage()

    private let fileQueue = DispatchQueue(label: "dayfold.customskin.file")
    private let directoryName = "Skins"

    private init() {}

    // MARK: - 目录

    /// `Documents/Skins/`，首次访问时创建。
    private var skinDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - 公共 API

    /// 保存封面图：JPEG 0.8 → `<notebookID>/`。
    /// - `filename`：一般固定为 `<notebookID>.jpg`。
    /// - 路径校验：`isValidFilename` 防穿越；UUID 字符串天然安全，但保留校验作为深度防御。
    func saveSkin(image: UIImage, filename: String, notebookID: UUID) async throws {
        guard Self.isValidFilename(filename) else {
            throw CustomSkinError.invalidFilename(filename)
        }

        // 中心裁剪 12:17，再编码 JPEG。
        let cropped = ImageCropper.cropToCoverAspect(image)
        guard let data = cropped.jpegData(compressionQuality: 0.8) else {
            throw CustomSkinError.encodeFailed
        }

        let url = fileURL(for: filename, notebookID: notebookID)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            fileQueue.async {
                do {
                    try data.write(to: url, options: .atomic)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 同步读取封面图。文件不存在返回 nil（不抛错）。
    func loadSkin(filename: String, notebookID: UUID) -> UIImage? {
        let url = fileURL(for: filename, notebookID: notebookID)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    /// 删除封面图。文件不存在视为成功（幂等）。
    func deleteSkin(filename: String, notebookID: UUID) {
        let url = fileURL(for: filename, notebookID: notebookID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 工具

    private func fileURL(for filename: String, notebookID: UUID) -> URL {
        // 用 notebookID 做子目录，避免文件名冲突 + 便于批量清理某个笔记本。
        skinDirectory
            .appendingPathComponent(notebookID.uuidString, isDirectory: true)
            .appendingPathComponent(filename)
    }

    /// 与 `MediaService` 风格一致：拒空、拒 `..`、拒路径分隔符。
    static func isValidFilename(_ name: String) -> Bool {
        guard !name.isEmpty,
              name != ".",
              name != "..",
              !name.contains("/"),
              !name.contains("\\"),
              !name.contains(":") else {
            return false
        }
        return true
    }
}

// MARK: - Errors

enum CustomSkinError: LocalizedError {
    case invalidFilename(String)
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidFilename(let s): return "非法文件名：\(s)"
        case .encodeFailed:           return "图片编码失败"
        }
    }
}
