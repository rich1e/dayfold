// Services/EntryPDFExporter.swift
import SwiftUI
import UIKit
import PDFKit

@MainActor
enum EntryPDFExporter {
    /// 将 entry 渲染为 PDF(文本型 + 图片插入),返回临时文件 URL;失败返回 nil
    static func renderPDF(entry: Entry, images: [UIImage]) -> URL? {
        let pageSize = CGSize(width: 595, height: 842)  // A4 72dpi
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let filename = filenameSlug(for: entry) + ".pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var y: CGFloat = margin
                let contentWidth = pageSize.width - 2 * margin

                // 标题
                if !entry.wrappedTitle.isEmpty {
                    let title = NSAttributedString(
                        string: entry.wrappedTitle,
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                            .foregroundColor: UIColor(Color.warmDark)
                        ]
                    )
                    title.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 40))
                    y += 48
                }

                // 元信息
                if let loc = entry.location {
                    let parts: [String] = [
                        loc.wrappedPlaceName,
                        loc.weatherTemperature > 0 || loc.weatherTemperature < 0
                            ? "\(Int(loc.weatherTemperature))°C"
                            : "",
                        loc.wrappedCondition
                    ].filter { !$0.isEmpty }
                    if !parts.isEmpty {
                        let meta = NSAttributedString(
                            string: parts.joined(separator: " · "),
                            attributes: [
                                .font: UIFont.systemFont(ofSize: 11),
                                .foregroundColor: UIColor(Color.warmBrown)
                            ]
                        )
                        meta.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: 16))
                        y += 24
                    }
                }

                // 正文
                if !entry.wrappedContent.isEmpty {
                    let content = NSAttributedString(
                        string: entry.wrappedContent,
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 14),
                            .foregroundColor: UIColor(Color.warmDark),
                            .paragraphStyle: {
                                let ps = NSMutableParagraphStyle()
                                ps.lineSpacing = 4
                                return ps
                            }()
                        ]
                    )
                    let remainingHeight = pageSize.height - y - margin
                    let contentRect = CGRect(x: margin, y: y, width: contentWidth, height: remainingHeight)
                    content.draw(with: contentRect,
                                 options: [.usesLineFragmentOrigin, .usesFontLeading],
                                 context: nil)
                }

                // 图片(独立页)
                let photoImages = images  // EntryDetailView 已过滤为图片类型
                if !photoImages.isEmpty {
                    ctx.beginPage()
                    var imgY: CGFloat = margin
                    let imgMaxWidth = contentWidth
                    let imgMaxHeight = pageSize.height - 2 * margin
                    for image in photoImages {
                        let scale = min(imgMaxWidth / max(image.size.width, 1),
                                        imgMaxHeight / max(image.size.height, 1),
                                        1)
                        let imgW = image.size.width * scale
                        let imgH = image.size.height * scale
                        if imgY + imgH > imgMaxHeight {
                            ctx.beginPage()
                            imgY = margin
                        }
                        let imgRect = CGRect(x: (pageSize.width - imgW) / 2,
                                             y: imgY, width: imgW, height: imgH)
                        image.draw(in: imgRect)
                        imgY += imgH + 12
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }

    private static func filenameSlug(for entry: Entry) -> String {
        let base = entry.wrappedTitle.isEmpty ? "Untitled" : entry.wrappedTitle
        let slug = base
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "\n", with: "")
        let prefix = String(entry.id?.uuidString.prefix(8) ?? "entry")
        return "\(prefix)-\(slug)"
    }
}
