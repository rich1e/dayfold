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

    func makeUIView(context: Context) -> UITextView {
        let tv = EditorTextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.textColor = .label
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

        // 同时检查当前已构建的 attributedText 是否与外部数据源同步；不同步立即重建
        let needsRebuild = context.coordinator.cachedImagesCount != images.count
            || context.coordinator.cachedText != text
            || (context.coordinator.cachedContainerWidth > 0 && abs(context.coordinator.lastUsedContainerWidth - context.coordinator.cachedContainerWidth) > 0.5)
        if needsRebuild {
            let width = uiView.bounds.width > 0 ? uiView.bounds.width : UIScreen.main.bounds.width - 32
            context.coordinator.rebuildAttributedTextIfNeeded(textView: uiView, forceContainerWidth: width)
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
        /// - Parameters:
        ///   - textView: 要更新的 UITextView
        ///   - forceContainerWidth: 当 cachedContainerWidth 还未就绪时使用的兜底宽度
        func rebuildAttributedTextIfNeeded(textView: UITextView, forceContainerWidth: CGFloat? = nil) {
            let width: CGFloat
            if cachedContainerWidth > 0 {
                width = cachedContainerWidth
            } else if let forced = forceContainerWidth, forced > 0 {
                width = forced
            } else {
                // 还没 layout 完，留待 viewDidLayoutSubviews 触发
                return
            }

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
                textColor: .label,
                containerWidth: width
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
            let width = textView.bounds.width > 0 ? textView.bounds.width : UIScreen.main.bounds.width
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
