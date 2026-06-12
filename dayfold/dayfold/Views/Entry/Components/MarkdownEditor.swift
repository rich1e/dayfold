// Views/Entry/Components/MarkdownEditor.swift
import SwiftUI

struct MarkdownEditor: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var isFullscreen = false

    var wordCount: Int
    var readingTime: Int

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.warmAccent)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.warmLight)
                }
            }

            // 全屏模式下的悬浮恢复按钮
            if isFullscreen {
                Button {
                    withAnimation {
                        isFullscreen = false
                    }
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.warmAccent)
                        .padding(10)
                        .background(Color.warmLight.opacity(0.9))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 12)
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
