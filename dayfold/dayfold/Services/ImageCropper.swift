// Services/ImageCropper.swift
import UIKit

/// 图片裁剪工具。当前只做一件事：把任意 `UIImage` 中心裁剪到笔记本封面比例 (12:17)。
///
/// 为什么独立：未来如果 EntryEditor 也要做封面裁剪 / 头像裁剪，可以共用这里。
enum ImageCropper {
    /// 笔记本封面比例（240×340 = 12:17），与 `NotebookCoverView` 几何对齐。
    static let coverAspect: CGFloat = 240.0 / 340.0

    /// 中心裁剪到封面比例。
    /// - 先用 `fixOrientation()` 校正 EXIF，避免相机照片方向错乱。
    /// - 取较短边为正方形边长，再按目标比例裁掉多余。
    /// - 输出 720×1020 渲染质量（与 `NotebookCoverView` 240×340 等比 3x）。
    static func cropToCoverAspect(_ image: UIImage) -> UIImage {
        let normalized = image.fixOrientation()
        let targetRatio = coverAspect // 宽 / 高 < 1(竖向)
        let width = normalized.size.width
        let height = normalized.size.height
        guard width > 0, height > 0 else { return normalized }

        // 当前比例宽/高
        let currentRatio = width / height

        let cropRect: CGRect
        if currentRatio > targetRatio {
            // 原图更宽 → 按高度裁两侧
            let newWidth = height * targetRatio
            let xOffset = (width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: height)
        } else {
            // 原图更高 → 按宽度裁上下
            let newHeight = width / targetRatio
            let yOffset = (height - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: width, height: newHeight)
        }

        // 用 scale 校正 retina，否则裁剪坐标 / 输出像素会偏差
        let scaled = CGRect(
            x: cropRect.origin.x * normalized.scale,
            y: cropRect.origin.y * normalized.scale,
            width: cropRect.size.width * normalized.scale,
            height: cropRect.size.height * normalized.scale
        )

        guard let cg = normalized.cgImage?.cropping(to: scaled) else { return normalized }
        return UIImage(cgImage: cg, scale: normalized.scale, orientation: .up)
    }
}

// MARK: - EXIF Orientation 修正

extension UIImage {
    /// UIImage 在相机照片 / EXIF 方向不为 1 时，CGContext 绘制会得到旋转图。
    /// 用 UIGraphicsImageRenderer 重绘一遍，固定 orientation = .up。
    func fixOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
