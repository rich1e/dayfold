// Views/Entry/Components/SelectableTextEditor.swift
import SwiftUI
import UIKit

/// 封装包含内联富文本/图片附件的 UITextView 编辑器。
///
/// 关键时序：
/// - `makeUIView` 阶段 `tv.bounds.width == 0`，不构建 attributedText；
///   等 `viewDidLayoutSubviews` 拿到真实宽度后才构建（避免图片用兜底宽度预渲染，
///   之后真实宽度变化时图片无法自适应）。
/// - 现有 `isUpdatingFromSwiftUI` / `cachedText` / `cachedImagesCount` / 异步 `onHeightChange`
///   防环机制全部保留。
struct SelectableTextEditor: UIViewRepresentable {
    @Binding var text: String
    var images: [String: UIImage] = [:]
    let onSelectionChange: (Int) -> Void
    /// false 时文本框自适应内容不滚动（配合外层 ScrollView 使用）
    var isScrollEnabled: Bool = true
    /// isScrollEnabled = false 时回报内容实高（sizeThatFits），供外层撑开 frame
    var onHeightChange: ((CGFloat) -> Void)? = nil
    /// 默认 .label 保持向后兼容；Theme 化时由调用方传入 theme.textPrimary.asUIColor
    var textColor: UIColor = .label

    func makeUIView(context: Context) -> UITextView {
        let tv = EditorTextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.textColor = textColor
        tv.isScrollEnabled = isScrollEnabled
        tv.alwaysBounceVertical = isScrollEnabled
        tv.keyboardDismissMode = .interactive
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        tv.textContainer.lineFragmentPadding = 0
        tv.coordinator = context.coordinator

        // 首次 make 时 tv.bounds.width == 0，留待 viewDidLayoutSubviews 拿到真实宽度后再构建
        // 但仍要保存初始 text/images 让 coordinator 在 layout 后能首次构建
        context.coordinator.textView = tv
        context.coordinator.pendingText = text
        context.coordinator.pendingImages = images
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // 缓存最新的外部数据，layout 时机由 EditorTextView.viewDidLayoutSubviews 触发重建
        context.coordinator.pendingText = text
        context.coordinator.pendingImages = images

        // 同时检查当前已构建的 attributedText 是否与外部数据源同步；不同步立即重建。
        // 注意：只在 bounds.width 已就绪时重建。首帧 / 重开编辑时 updateUIView 早于 layoutSubviews，
        // 此时 bounds.width == 0，若用 UIScreen 宽度兜底会按错误宽度预渲染图片，
        // 并把 lastUsedContainerWidth 写成假值。layoutSubviews 随后必然带真实宽度回来触发重建，
        // 所以这里直接跳过即可。
        let needsRebuild = context.coordinator.cachedImagesCount != images.count
            || context.coordinator.cachedText != text
        if needsRebuild, uiView.bounds.width > 0 {
            context.coordinator.rebuildAttributedTextIfNeeded(textView: uiView)
        }

        if uiView.isScrollEnabled != isScrollEnabled {
            uiView.isScrollEnabled = isScrollEnabled
            uiView.alwaysBounceVertical = isScrollEnabled
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// 自定义 UITextView 子类，在 layout 阶段触发 Coordinator 首次/重新构建 attributedText
    final class EditorTextView: UITextView {
        weak var coordinator: Coordinator?

        /// SwiftUI 分配给本视图的宽度。非滚动 UITextView 的 contentSize.width 会被
        /// 超宽内容（attachment / 长英文单词）撑大，而 UITextView 又把它报成 intrinsicContentSize.width，
        /// SwiftUI 采纳后整个 VStack 被横向撑宽 → 标题、日期、右上「完毕」被推出屏幕两侧。
        /// 因此这里锁死横向 intrinsic，只让高度参与自适应。
        override var intrinsicContentSize: CGSize {
            let sup = super.intrinsicContentSize
            return CGSize(width: UIView.noIntrinsicMetric, height: sup.height)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let coordinator = coordinator else { return }
            let width = bounds.width
            guard width > 0 else { return }
            coordinator.cachedContainerWidth = width
            coordinator.rebuildAttributedTextIfNeeded(textView: self)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextEditor
        weak var textView: UITextView?

        // MARK: - 数据缓存（驱动 rebuild）
        /// 最新一次 SwiftUI 传入的 text，由 updateUIView 持续写入
        var pendingText: String = ""
        /// 最新一次 SwiftUI 传入的 images
        var pendingImages: [String: UIImage] = [:]

        // MARK: - 重建相关状态
        /// 最近一次真实 layout 拿到的容器宽度（pt）
        var cachedContainerWidth: CGFloat = 0
        /// 最近一次构建 attributedText 时使用的 containerWidth
        var lastUsedContainerWidth: CGFloat = 0
        /// 最近构建 attributedText 时同步的 text（避免无变化重复构建）
        var cachedText: String = ""
        /// 最近构建 attributedText 时 imagesMap 数量
        var cachedImagesCount: Int = 0
        /// 最近构建时 imagesMap 的 keys hash（避免 count 不变但内容变）
        var cachedImagesKeys: String = ""

        // MARK: - 防环状态
        /// 最近一次回报给 SwiftUI 的高度
        var cachedHeight: CGFloat = -1
        /// 最近一次回报的选区长度
        var cachedSelectionLength: Int = -1
        /// updateUIView 重排 attributedText 期间为 true，屏蔽 delegate 反向回写
        var isUpdatingFromSwiftUI: Bool = false

        init(_ parent: SelectableTextEditor) {
            self.parent = parent
            self.pendingText = parent.text
            self.pendingImages = parent.images
            self.cachedText = parent.text
            self.cachedImagesCount = parent.images.count
            self.cachedImagesKeys = parent.images.keys.sorted().joined()
        }

        /// 根据 pendingText/pendingImages 与 cachedContainerWidth 判断是否需要重建 attributedText。
        /// 只在 layoutSubviews 拿到真实 bounds.width 后调用，不接受兜底宽度：
        /// 用假宽度预渲染图片会让 lastUsedContainerWidth 记下假值，后续真实宽度到位时反而可能被判定为「无需重建」。
        /// - Parameter textView: 要更新的 UITextView
        func rebuildAttributedTextIfNeeded(textView: UITextView) {
            guard cachedContainerWidth > 0 else {
                // 还没 layout 完，留待 layoutSubviews 触发
                return
            }
            let width = cachedContainerWidth

            // attachment 可用宽度只能由 bounds.width 减去「我们自己设定的」inset 与 padding 推导，
            // 绝不能回读 textContainer.size.width：
            // 非滚动 UITextView 的 textContainer 会被超宽 attachment 反向撑宽，
            // 回读到的是「已被上一次超宽图污染」的值，再拿去渲染下一张图 → 每次 layout 宽度递增，
            // 表现为图片撑爆整屏 / 整个界面被横向推出屏幕（左侧标题、右侧「完毕」被裁）。
            let insetH = textView.textContainerInset.left + textView.textContainerInset.right
            let padding = textView.textContainer.lineFragmentPadding * 2
            let effectiveWidth = max(1, width - insetH - padding)

            let keys = pendingImages.keys.sorted().joined()
            let needsRebuild = cachedText != pendingText
                || cachedImagesCount != pendingImages.count
                || cachedImagesKeys != keys
                || abs(lastUsedContainerWidth - width) > 0.5

            guard needsRebuild else { return }

            let attrText = RichTextMarkdownParser.attributedString(
                from: pendingText,
                images: pendingImages,
                font: UIFont.preferredFont(forTextStyle: .body),
                textColor: parent.textColor,
                containerWidth: effectiveWidth
            )

            let selectedRange = textView.selectedRange
            isUpdatingFromSwiftUI = true
            textView.attributedText = attrText
            textView.selectedRange = selectedRange
            isUpdatingFromSwiftUI = false

            cachedText = pendingText
            cachedImagesCount = pendingImages.count
            cachedImagesKeys = keys
            lastUsedContainerWidth = width

            reportHeight(textView)
        }

        // MARK: - UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            // SwiftUI 正在主动刷新 attributedText 时不要反向回写 @Binding text
            if isUpdatingFromSwiftUI { return }

            let (markdown, _) = RichTextMarkdownParser.markdown(from: textView.attributedText)
            guard markdown != parent.text else {
                reportHeight(textView)
                return
            }
            parent.text = markdown
            cachedText = markdown
            reportHeight(textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let length = textView.selectedRange.length
            guard length != cachedSelectionLength else { return }
            cachedSelectionLength = length
            let parent = self.parent
            DispatchQueue.main.async {
                parent.onSelectionChange(length)
            }
        }

        /// 回报当前内容实高，变化时异步派发避免在 view update 周期同步写入 @State
        func reportHeight(_ textView: UITextView) {
            guard !textView.isScrollEnabled else { return }
            // 只用真实 bounds.width 测量；宽度未就绪时不回报（layoutSubviews 会再触发一次）。
            // 早期用 UIScreen 宽度兜底会把高度按错误宽度算出来，外层 frame 随即被写成错值。
            let width = textView.bounds.width
            guard width > 0 else { return }
            let targetSize = CGSize(width: width, height: .greatestFiniteMagnitude)
            let height = max(textView.sizeThatFits(targetSize).height, 120)
            guard abs(height - cachedHeight) > 0.5 else { return }
            cachedHeight = height
            let parent = self.parent
            DispatchQueue.main.async {
                parent.onHeightChange?(height)
            }
        }
    }
}
