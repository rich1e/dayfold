// Views/Entry/Components/MarkdownEditor.swift
import SwiftUI

struct MarkdownEditor: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var isFullscreen = false

    var wordCount: Int
    var readingTime: Int

    var body: some View {
        VStack(spacing: 0) {
            if !isFullscreen {
                // 工具栏
                FormattingToolbar(text: $text, isFocused: $isFocused)
                    .background(Color.warmLight)

                Divider()
            }

            // 编辑区域
            TextEditor(text: $text)
                .focused($isFocused)
                .font(.warmBody)
                .scrollContentBackground(.hidden)
                .background(Color.warmPaper)
                .padding(.horizontal, isFullscreen ? 20 : 16)

            if !isFullscreen {
                Divider()

                // 状态栏
                HStack {
                    Text("\(wordCount) 字")
                        .font(.warmCaption)
                        .foregroundColor(.warmBrown)

                    Text("·")
                        .foregroundColor(.warmGray)

                    Text("约 \(readingTime) 分钟阅读")
                        .font(.warmCaption)
                        .foregroundColor(.warmBrown)

                    Spacer()

                    Button {
                        withAnimation {
                            isFullscreen.toggle()
                        }
                    } label: {
                        Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.warmAccent)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.warmLight)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    MarkdownEditor(
        text: .constant("# 标题\n\n这是一段**粗体**和*斜体*文字。"),
        wordCount: 15,
        readingTime: 1
    )
}
