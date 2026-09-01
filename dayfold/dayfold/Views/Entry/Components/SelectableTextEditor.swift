// Views/Entry/Components/SelectableTextEditor.swift
import SwiftUI
import UIKit

/// SwiftUI `TextEditor` 无法直接读取 `selectedRange`，
/// 这里包一层 `UITextView`，通过 Coordinator 监听选区变化回调给 SwiftUI。
///
/// 使用：
/// ```swift
/// SelectableTextEditor(text: $viewModel.content) { len in
///     selectionLength = len
/// }
/// ```
struct SelectableTextEditor: UIViewRepresentable {
    @Binding var text: String
    let onSelectionChange: (Int) -> Void

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true
        tv.textColor = .label
        tv.alwaysBounceVertical = true
        tv.keyboardDismissMode = .interactive
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        tv.text = text
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: SelectableTextEditor
        init(_ parent: SelectableTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.onSelectionChange(textView.selectedRange.length)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var text = "选中这段文字试试"
        @State var len = 0
        var body: some View {
            VStack {
                SelectableTextEditor(text: $text) { len = $0 }
                    .frame(height: 200)
                Text("selection length = \(len)")
            }
        }
    }
    return PreviewWrapper()
}