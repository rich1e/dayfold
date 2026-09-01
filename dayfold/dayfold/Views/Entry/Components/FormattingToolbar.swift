// Views/Entry/Components/FormattingToolbar.swift
import SwiftUI

struct FormattingToolbar: View {
    @Binding var text: String

    /// 可选焦点绑定：传入时调用 `isFocused = true` 把焦点回写文本框；不传入则跳过（适用于选中态/外置键盘 accessory 等不依赖 FocusState 的场景）
    var isFocused: FocusState<Bool>.Binding?

    /// `true` 时按钮仅渲染图标，不显示下方 title 文字（用于紧凑场景，如选中态键盘 accessory）
    var compact: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: compact ? 8 : 16) {
                ToolbarButton(icon: "bold", title: "粗体", compact: compact) {
                    insertMarkdown("**", "**")
                }

                ToolbarButton(icon: "italic", title: "斜体", compact: compact) {
                    insertMarkdown("*", "*")
                }

                ToolbarButton(icon: "list.bullet", title: "列表", compact: compact) {
                    insertMarkdown("\n- ", "")
                }

                ToolbarButton(icon: "number", title: "编号列表", compact: compact) {
                    insertMarkdown("\n1. ", "")
                }

                ToolbarButton(icon: "quote.opening", title: "引用", compact: compact) {
                    insertMarkdown("\n> ", "")
                }

                ToolbarButton(icon: "link", title: "链接", compact: compact) {
                    insertMarkdown("[", "](url)")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, compact ? 4 : 8)
        }
        .background(Color.warmLight)
    }

    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        text.insert(contentsOf: prefix, at: text.endIndex)
        text.insert(contentsOf: suffix, at: text.endIndex)
        isFocused?.wrappedValue = true
    }
}

struct ToolbarButton: View {
    let icon: String
    let title: String
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: compact ? 0 : 4) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 16 : 18))
                if !compact {
                    Text(title)
                        .font(.system(size: 10))
                }
            }
            .foregroundColor(.warmBrown)
            .frame(width: compact ? 36 : 50)
        }
    }
}
