// Services/RichTextMarkdownParser.swift
import UIKit

/// 自定义 NSTextAttachment：构造期立即按容器可用宽度等比预渲染图片到 `self.image`，
/// UIKit 渲染时直接走 `self.image` 标准路径（带解码缓存、性能最佳）。
///
/// 设计依据：UIKit 渲染 attachment 优先用 `self.image`；`image(forBounds:)` 是 fallback，
/// 在 self.image==nil 时才调用，且重绘 4032×3024 原图到目标尺寸会生成 ~30MB 中间位图
/// 触发 iOS 内存压力导致静默失败（图片不显示）。"init 期预渲染 self.image"是 petehare.com、
/// RichTextKit、canopas/rich-editor-swiftui 等成熟实现的共识做法。
final class ImageTextAttachment: NSTextAttachment {
    /// 构造期已算好的目标尺寸，attachmentBounds 直接返回
    let displaySize: CGSize
    /// 关联的文件名（Markdown `![](filename)` 标记中的 filename）
    let filename: String?

    /// - Parameters:
    ///   - image: 原图
    ///   - filename: Markdown 文件名；nil 表示匿名 attachment
    ///   - containerWidth: 当前可用容器宽度（pt）；传 0 时兜底为 `UIScreen.main.bounds.width - 32`
    init(image: UIImage, filename: String?, containerWidth: CGFloat) {
        // 0) 全程防御 NaN / 零 / 无穷：CoreGraphics 在 size 为 0 或 NaN 时会直接报错。
        var safeWidth = containerWidth
        if !safeWidth.isFinite || safeWidth <= 0 {
            safeWidth = UIScreen.main.bounds.width - 32
        }
        if !safeWidth.isFinite || safeWidth <= 0 {
            safeWidth = 343  // 兜底兜底（iPad/多屏极端情况）
        }

        var imgSize = image.size
        if !imgSize.width.isFinite || imgSize.width <= 0 { imgSize.width = safeWidth }
        if !imgSize.height.isFinite || imgSize.height <= 0 { imgSize.height = safeWidth }

        // 1) 计算等比缩放后的目标尺寸
        var width = safeWidth
        var height = imgSize.height * (safeWidth / imgSize.width)
        if !height.isFinite || height <= 0 { height = safeWidth }
        if !width.isFinite || width <= 0 { width = safeWidth }

        // 硬性兜底：最大高度不超过容器宽度（避免极长竖图撑爆）
        if height > safeWidth {
            height = safeWidth
            width = imgSize.width * (height / max(imgSize.height, 1))
            if !width.isFinite || width <= 0 { width = safeWidth }
        }

        // 最终兜底：尺寸必须在 (0, 10000) 区间
        width = min(max(width, 1), 10000)
        height = min(max(height, 1), 10000)
        let displaySize = CGSize(width: width, height: height)

        // 2) 用 UIGraphicsImageRenderer 一次性预渲染到 displaySize（主线程，仅一次）
        let format = UIGraphicsImageRendererFormat.default()
        let screenScale = UIScreen.main.scale
        format.scale = screenScale.isFinite && screenScale > 0 ? screenScale : 2.0
        let renderer = UIGraphicsImageRenderer(size: displaySize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: displaySize))
        }

        // 3) 关键：把缩放后的图赋给 self.image，让 UIKit 走标准渲染路径
        self.displaySize = displaySize
        self.filename = filename
        super.init(data: nil, ofType: nil)
        self.image = resized
    }

    required init?(coder: NSCoder) {
        self.displaySize = .zero
        self.filename = nil
        super.init(coder: coder)
    }

    /// 直接返回预计算的 displaySize，UIKit 用此值决定 attachment 在 layout 中的占位
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        return CGRect(origin: .zero, size: displaySize)
    }
}

/// 负责纯文本 Markdown 与带 NSTextAttachment 的 NSAttributedString 之间的双向转换
enum RichTextMarkdownParser {
    static let defaultFont = UIFont.preferredFont(forTextStyle: .body)
    static let defaultTextColor = UIColor.label

    /// 匹配 Markdown 图片语法: ![](filename) 或 ![alt](filename)
    private static let imageRegex = try! NSRegularExpression(
        pattern: #"!\[(.*?)\]\((.*?)\)"#,
        options: []
    )

    /// 文本段落样式：4pt 行距，提升正文可读性
    private static func makeTextParagraphStyle() -> NSMutableParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 4
        ps.paragraphSpacing = 4
        ps.paragraphSpacingBefore = 0
        return ps
    }

    /// 附件段落样式：紧凑行距、零段落间距，图片上下紧贴文字
    private static func makeAttachmentParagraphStyle() -> NSMutableParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 0
        ps.paragraphSpacing = 0
        ps.paragraphSpacingBefore = 0
        ps.lineHeightMultiple = 1.0
        return ps
    }

    /// Markdown 转换为 NSAttributedString
    /// - Parameters:
    ///   - markdown: 含 ![](filename) 的正文字符串
    ///   - images: 预加载的 [filename: UIImage] 字典
    ///   - containerWidth: 容器可用宽度（pt）；用于构造期图片预渲染，传 0 兜底为屏幕宽-32
    /// - Returns: 可直接给 UITextView.attributedText 使用的富文本
    static func attributedString(
        from markdown: String,
        images: [String: UIImage],
        font: UIFont = defaultFont,
        textColor: UIColor = defaultTextColor,
        containerWidth: CGFloat = 0
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let nsString = markdown as NSString
        var lastLocation = 0

        let matches = imageRegex.matches(in: markdown, options: [], range: NSRange(location: 0, length: nsString.length))

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: makeTextParagraphStyle()
        ]
        let attachmentAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: makeAttachmentParagraphStyle()
        ]

        /// 把位置在 [start, end) 的纯文本以指定属性追加
        func appendText(in range: NSRange, attributes: [NSAttributedString.Key: Any]) {
            guard range.length > 0 else { return }
            let plain = nsString.substring(with: range)
            result.append(NSAttributedString(string: plain, attributes: attributes))
        }

        for match in matches {
            // 匹配项之前的普通文本
            let textRange = NSRange(location: lastLocation, length: match.range.location - lastLocation)
            appendText(in: textRange, attributes: textAttributes)

            // 提取图片文件名 (group 2)
            let filenameRange = match.range(at: 2)
            let filename = nsString.substring(with: filenameRange)

            if let img = images[filename] {
                // 构造期预渲染到目标尺寸赋给 self.image，让 UIKit 走标准路径
                let attachmentStart = result.length
                let attachment = ImageTextAttachment(image: img, filename: filename, containerWidth: containerWidth)
                result.append(NSAttributedString(attachment: attachment))
                let attachmentEnd = result.length

                // 吸收紧随图片之后的一个 \n（典型由 addPickedPhotos 追加）
                // 让该换行也走紧凑样式，避免被文本段 lineSpacing=4 + 字体行高撑出大空白
                let newlineProbe = NSRange(location: attachmentEnd, length: min(1, nsString.length - (match.range.location + match.range.length)))
                var consumedNewline = false
                if newlineProbe.length == 1 {
                    let ch = nsString.substring(with: newlineProbe)
                    if ch == "\n" {
                        appendText(in: newlineProbe, attributes: attachmentAttributes)
                        consumedNewline = true
                    }
                }

                // 覆盖附件字符（含上面可能含的换行）的段落属性
                let attachmentRange = NSRange(
                    location: attachmentStart,
                    length: result.length - attachmentStart
                )
                result.addAttributes(attachmentAttributes, range: attachmentRange)
                _ = consumedNewline

                lastLocation = match.range.location + match.range.length + (consumedNewline ? 1 : 0)
            } else {
                // 如果图片尚未加载就位，先保留原始文本或占位
                let fallbackText = nsString.substring(with: match.range)
                result.append(NSAttributedString(string: fallbackText, attributes: textAttributes))
                lastLocation = match.range.location + match.range.length
            }
        }

        // 追加剩余尾部文本
        let tailRange = NSRange(location: lastLocation, length: nsString.length - lastLocation)
        appendText(in: tailRange, attributes: textAttributes)

        return result
    }

    /// NSAttributedString 序列化为 Markdown 字符串并提取附件顺序
    /// - Parameter attributedString: UITextView 的 attributedText
    /// - Returns: (markdown: 含 ![](filename) 的文本, filenames: 按顺序出现的图片文件名列表)
    static func markdown(from attributedString: NSAttributedString) -> (markdown: String, filenames: [String]) {
        var markdown = ""
        var filenames: [String] = []

        let length = attributedString.length
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: length), options: []) { attributes, range, _ in
            if let attachment = attributes[.attachment] as? ImageTextAttachment, let filename = attachment.filename {
                markdown += "![](\(filename))"
                filenames.append(filename)
            } else if let attachment = attributes[.attachment] as? NSTextAttachment {
                // 兜底：未标记文件名的通用附件，若有图片则自动生成临时文件名
                let tempName = "\(UUID().uuidString).jpg"
                markdown += "![](\(tempName))"
                filenames.append(tempName)
            } else {
                let substring = attributedString.attributedSubstring(from: range).string
                markdown += substring
            }
        }

        return (markdown, filenames)
    }
}
