// Services/EntryMarkdownExporter.swift
import Foundation

@MainActor
enum EntryMarkdownExporter {
    /// 将 entry 渲染为 Obsidian 风格 Markdown (front-matter + 正文 + 未内联图片附件)
    static func renderMarkdown(entry: Entry) -> String {
        var md = ""

        // front-matter (YAML)
        md += "---\n"
        let title = entry.wrappedTitle.isEmpty ? "Untitled" : entry.wrappedTitle
        md += "title: \(yamlEscaped(title))\n"
        if let date = entry.createdAt {
            md += "date: \(ISO8601DateFormatter().string(from: date))\n"
        }
        if let modified = entry.modifiedAt, modified != entry.createdAt {
            md += "modified: \(ISO8601DateFormatter().string(from: modified))\n"
        }
        if !entry.tagsArray.isEmpty {
            md += "tags: ["
            md += entry.tagsArray.map { $0.wrappedName }.joined(separator: ", ")
            md += "]\n"
        }
        if let loc = entry.location {
            md += "location: \(yamlEscaped(loc.wrappedPlaceName))\n"
        }
        if !entry.wrappedMood.isEmpty {
            md += "mood: \(yamlEscaped(entry.wrappedMood))\n"
        }
        md += "---\n\n"

        // 标题
        if !entry.wrappedTitle.isEmpty {
            md += "# \(entry.wrappedTitle)\n\n"
        }

        // 元信息行
        if let loc = entry.location {
            let parts: [String] = [
                loc.wrappedPlaceName,
                loc.weatherTemperature > 0 || loc.weatherTemperature < 0
                    ? "\(Int(loc.weatherTemperature))°C"
                    : "",
                loc.wrappedCondition
            ].filter { !$0.isEmpty }
            if !parts.isEmpty {
                md += "*\(parts.joined(separator: " · "))*\n\n"
            }
        }

        // 正文 (天然已包含 ![](filename))
        md += entry.wrappedContent
        if !entry.wrappedContent.isEmpty && !entry.wrappedContent.hasSuffix("\n") {
            md += "\n"
        }
        md += "\n"

        // 仅对于正文中尚未包含 ![] 标记的额外图片附件（如老数据），在文末以附件形式列出
        let photoAssets = entry.mediaAssetsArray.filter { $0.mediaType == .photo }
        let unreferencedPhotos = photoAssets.filter { !entry.wrappedContent.contains($0.wrappedFilename) }
        if !unreferencedPhotos.isEmpty {
            md += "## 附件\n\n"
            for asset in unreferencedPhotos {
                md += "- ![](\(asset.wrappedFilename))\n"
            }
        }

        return md
    }

    /// 将 Markdown 写入临时目录,返回 URL
    static func writeTempFile(_ markdown: String, entry: Entry) -> URL? {
        let filename = filenameSlug(for: entry) + ".md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func yamlEscaped(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
        return "\"\(escaped)\""
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
