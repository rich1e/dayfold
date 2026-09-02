// Views/Entry/EntryEditorView.swift
import SwiftUI
import CoreData
import UIKit

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EntryEditorViewModel
    @FocusState private var titleFocused: Bool
    @State private var showingImagePicker = false
    @State private var showingTagSelector = false
    @State private var selectionLength: Int = 0
    @State private var showingDeleteConfirm = false
    @State private var textHeight: CGFloat = 120
    /// 「是，使用」已消费 pendingMetadata，防止 alert dismiss 的 set false 误触发 decline
    @State private var metadataConfirmConsumed = false

    init(entry: Entry? = nil, context: NSManagedObjectContext, prefillDate: Date? = nil, notebook: Notebook? = nil) {
        _viewModel = StateObject(wrappedValue: EntryEditorViewModel(
            context: context, entry: entry, prefillDate: prefillDate, notebook: notebook))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.warmPaper.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                metaBar
                editorArea
            }

            // 随键盘移动的工具栏
            keyboardToolbar
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .fullScreenCover(isPresented: $showingImagePicker) {
            PhotoLibraryPickerView { picked in
                viewModel.addPickedPhotos(picked)
            }
        }
        .sheet(isPresented: $showingTagSelector) {
            TagSelectorSheet(selectedTags: $viewModel.selectedTags)
        }
        .alert("确定取消编辑吗？已保存的内容将恢复为修改前", isPresented: $showingDeleteConfirm) {
            Button("取消编辑", role: .destructive) {
                Task {
                    await viewModel.cancel()
                    dismiss()
                }
            }
            Button("继续编辑", role: .cancel) {}
        }
        .alert("保存失败", isPresented: Binding(
            get: { viewModel.lastSaveError != nil },
            set: { if !$0 { viewModel.lastSaveError = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.lastSaveError?.localizedDescription ?? "请重试")
        }
        .alert("使用附件时间和位置？", isPresented: Binding(
            get: { viewModel.pendingMetadata != nil },
            set: { if !$0 {
                if !metadataConfirmConsumed { viewModel.declineApplyPhotoMetadata() }
                metadataConfirmConsumed = false
            }}
        )) {
            Button("是，使用") {
                metadataConfirmConsumed = true
                viewModel.confirmApplyPhotoMetadata()
            }
            Button("否，保持不变", role: .cancel) {
                metadataConfirmConsumed = true
                viewModel.declineApplyPhotoMetadata()
            }
        } message: {
            metadataMessage
        }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack(spacing: 0) {
            // 日期时间
            Text(dateString)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.warmDark)

            Spacer()

            // 三点 Menu：标签 / 心情 / 删除
            Menu {
                Button {
                    showingTagSelector = true
                } label: {
                    Label("标签", systemImage: "tag")
                }

                Divider()

                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("删除", systemImage: "trash")
                }

            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.warmBrown)
                    .frame(width: 36, height: 36)
            }

            // 完成
            Button {
                saveAndDismiss()
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.warmAccent)
                        .scaleEffect(0.8)
                        .frame(width: 44, height: 32)
                } else {
                    Text("完毕")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.warmAccent)
                        .frame(height: 32)
                }
            }
            .disabled(viewModel.isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.warmPaper)
    }

    // MARK: - 元信息栏（只读）

    private var metaBar: some View {
        HStack(spacing: 6) {
            Text(viewModel.notebookDisplayName)
                .font(.system(size: 12))
                .foregroundColor(.warmBrown)

            if let place = viewModel.placeName, !place.isEmpty {
                Text("·")
                    .foregroundColor(.warmBrown)
                    .font(.system(size: 12))
                Text(place)
                    .font(.system(size: 12))
                    .foregroundColor(.warmBrown)
                    .lineLimit(1)
            }

            if let weather = viewModel.weather {
                Text("·")
                    .foregroundColor(.warmBrown)
                    .font(.system(size: 12))
                Image(systemName: weather.symbolName)
                    .font(.system(size: 11))
                    .foregroundColor(.warmBrown)
                Text("\(Int(weather.temperature))°C")
                    .font(.system(size: 12))
                    .foregroundColor(.warmBrown)
            }

            MoodSelector(mood: $viewModel.mood)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.warmPaper)
    }

    // MARK: - 编辑区（外层 ScrollView：正文自适应高度 + 图文混排内嵌）

    private var editorArea: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // 标题
                    TextField("标题", text: $viewModel.title, axis: .vertical)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.warmDark)
                        .focused($titleFocused)
                        .submitLabel(.next)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    // 正文 SelectableTextEditor（不自身滚动，随内容撑高，内嵌图片附件）
                    SelectableTextEditor(
                        text: $viewModel.content,
                        images: viewModel.imagesMap,
                        onSelectionChange: { len in
                            selectionLength = len
                        },
                        isScrollEnabled: false,
                        onHeightChange: { textHeight = $0 }
                    )
                    .frame(height: max(120, textHeight))
                    .id("editorAnchor")

                    // 已选标签 chip 行
                    if !viewModel.selectedTags.isEmpty {
                        SelectedTagsRow(tags: viewModel.selectedTags) { tag in
                            viewModel.removeTag(tag)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    // 键盘工具栏高度占位
                    Spacer().frame(height: 56)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: textHeight) { oldValue, newValue in
                // 正文长高（新增行/插入图片）时滚到正文底，保证光标可见
                if newValue > oldValue {
                    withAnimation { proxy.scrollTo("editorAnchor", anchor: .bottom) }
                }
            }
        }
        .background(Color.warmPaper)
    }

    // MARK: - 键盘工具栏（随键盘浮动）

    private var keyboardToolbar: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                // 条件追加：选中字符时显示格式化行
                if selectionLength > 0 {
                    Divider()
                    FormattingToolbar(text: $viewModel.content, compact: true)
                }

                // 基线行
                HStack(spacing: 0) {
                    // 收起键盘
                    toolbarButton(icon: "chevron.down") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }

                    Spacer()

                    // AI 占位（disabled）
                    toolbarButton(icon: "sparkles", disabled: true) {}

                    // 图片
                    toolbarButton(icon: "photo.on.rectangle") {
                        showingImagePicker = true
                    }

                    // 附件（占位）
                    toolbarButton(icon: "paperclip") {}

                    // 切换输入法（系统 keyboard 图标）
                    toolbarButton(icon: "keyboard") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.becomeFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 44)
                .background(Color.warmLight)
            }
        }
        .keyboardAdaptive()
    }

    // MARK: - Helpers

    private func toolbarButton(icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(disabled ? Color.warmBrown.opacity(0.4) : Color.warmDark.opacity(0.85))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
    }

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月d日 EEEE  HH:mm"
        return fmt.string(from: viewModel.effectiveDate)
    }

    /// 「使用附件时间和位置？」弹窗正文：时间行 + 位置行（地名异步就位后自动刷新）
    private var metadataMessage: Text {
        guard let meta = viewModel.pendingMetadata else { return Text("") }
        var lines: [String] = []
        if let date = meta.createdAt {
            lines.append("时间：\(formattedDate(date))")
        }
        if meta.coordinate != nil {
            lines.append(meta.placeName.map { "位置：\($0)" } ?? "位置：解析中…")
        }
        return lines.map { Text($0) }.reduce(Text(""), +)
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月d日 EEEE HH:mm"
        return fmt.string(from: date)
    }

    private func saveAndDismiss() {
        Task {
            _ = await viewModel.save()
            dismiss()
        }
    }
}

// MARK: - 键盘自适应修饰符

private struct KeyboardAdaptiveModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notif in
                guard let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                let screenHeight = UIScreen.main.bounds.height
                let newHeight = max(0, screenHeight - frame.minY)
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = newHeight
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
    }
}

private extension View {
    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptiveModifier())
    }
}

private struct MoodSelector: View {
    @Binding var mood: String
    private let options: [(symbol: String, value: String)] = [
        ("face.dashed", "blank"),
        ("cloud", "cloudy"),
        ("sun.max", "sunny"),
        ("moon.stars", "night"),
        ("sparkles", "sparkle")
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.value) { option in
                Button {
                    mood = (mood == option.value) ? "" : option.value
                } label: {
                    Image(systemName: option.symbol)
                        .font(.system(size: 14, weight: mood == option.value ? .semibold : .regular))
                        .foregroundColor(mood == option.value ? .warmAccent : .warmBrown)
                        .frame(width: 24, height: 24)
                }
            }
        }
    }
}

#Preview {
    let context = CoreDataStack.shared.viewContext
    EntryEditorView(context: context)
        .environment(\.managedObjectContext, context)
}
