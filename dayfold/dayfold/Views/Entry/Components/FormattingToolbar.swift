// Views/Entry/Components/FormattingToolbar.swift
import SwiftUI

struct FormattingToolbar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ToolbarButton(icon: "bold", title: "粗体") {
                    insertMarkdown("**", "**")
                }

                ToolbarButton(icon: "italic", title: "斜体") {
                    insertMarkdown("*", "*")
                }

                ToolbarButton(icon: "list.bullet", title: "列表") {
                    insertMarkdown("\n- ", "")
                }

                ToolbarButton(icon: "number", title: "编号列表") {
                    insertMarkdown("\n1. ", "")
                }

                ToolbarButton(icon: "quote.opening", title: "引用") {
                    insertMarkdown("\n> ", "")
                }

                ToolbarButton(icon: "link", title: "链接") {
                    insertMarkdown("[", "](url)")
                }

                ToolbarButton(icon: "checkmark.square", title: "待办") {
                    insertMarkdown("\n- [ ] ", "")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.warmLight)
    }

    private func insertMarkdown(_ prefix: String, _ suffix: String) {
        text.insert(contentsOf: prefix, at: text.endIndex)
        text.insert(contentsOf: suffix, at: text.endIndex)
        isFocused = true
    }
}

struct ToolbarButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(.warmBrown)
            .frame(width: 50)
        }
    }
}
