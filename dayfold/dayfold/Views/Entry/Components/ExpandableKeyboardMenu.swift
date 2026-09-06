// Views/Entry/Components/ExpandableKeyboardMenu.swift
import SwiftUI
import UIKit

/// 可展开键盘工具栏：折叠态只显示 sparkles 触发器；展开态显示 chevron.down / photo / paperclip / keyboard + 选中态时的 FormattingToolbar。
/// 切换由 `withAnimation(.interactiveSpring)` 触发，`.opacity` / `.scaleEffect` 自身实现 `VectorArithmetic`，SwiftUI 自动逐帧插值。
/// 视觉：暖色主题；触发器容器 `.ultraThinMaterial`；菜单内容 `theme.backgroundSecondary`。
/// 部署目标：iOS 18.1（不使用 iOS 26 glass API）。
struct ExpandableKeyboardMenu: View {
    @Environment(\.theme) private var theme

    @Binding var text: String
    /// `selectionLength` 由 `SelectableTextEditor.onSelectionChange` 写入；本组件只读，不回写
    let selectionLength: Int
    @Binding var showingImagePicker: Bool

    @State private var isExpanded: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // 折叠态：sparkles 圆形触发器
            CollapsedTrigger()
                .opacity(isExpanded ? 0 : 1)
                .scaleEffect(isExpanded ? 0.7 : 1)
                .allowsHitTesting(!isExpanded)
                .onTapGesture { toggle() }

            // 展开态：完整工具栏（含选中态 FormattingToolbar）
            ExpandedContent(
                text: $text,
                selectionLength: selectionLength,
                showingImagePicker: $showingImagePicker,
                onCollapse: { toggle() }
            )
            .opacity(isExpanded ? 1 : 0)
            .scaleEffect(isExpanded ? 1 : 0.85, anchor: .trailing)
            .allowsHitTesting(isExpanded)
        }
        .frame(
            height: isExpanded ? expandedHeight : 60,
            alignment: .bottom
        )
        .animation(
            .interactiveSpring(response: 0.45, dampingFraction: 0.75),
            value: isExpanded
        )
        .animation(
            .interactiveSpring(response: 0.45, dampingFraction: 0.75),
            value: selectionLength
        )
    }

    private var expandedHeight: CGFloat {
        selectionLength > 0 ? 96 : 60
    }

    private func toggle() {
        withAnimation(.interactiveSpring(response: 0.45, dampingFraction: 0.75)) {
            isExpanded.toggle()
        }
    }
}

// MARK: - 折叠态触发器

private struct CollapsedTrigger: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 18, weight: .regular))
            .foregroundColor(theme.textPrimary.opacity(0.85))
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(theme.dividerSubtle, lineWidth: 0.5))
            .padding(.bottom, 8)
    }
}

// MARK: - 展开态内容

private struct ExpandedContent: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
    let selectionLength: Int
    @Binding var showingImagePicker: Bool
    let onCollapse: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if selectionLength > 0 {
                Divider().background(theme.dividerSubtle)
                FormattingToolbar(text: $text, compact: true)
            }

            HStack(spacing: 0) {
                toolbarButton(icon: "chevron.down") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }

                Spacer()

                toolbarButton(icon: "photo.on.rectangle") {
                    showingImagePicker = true
                }

                toolbarButton(icon: "paperclip") {}

                toolbarButton(icon: "keyboard") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.becomeFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }

                toolbarButton(icon: "sparkles", action: onCollapse)
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .background(theme.backgroundSecondary)
        }
    }

    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(theme.textPrimary.opacity(0.85))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}
