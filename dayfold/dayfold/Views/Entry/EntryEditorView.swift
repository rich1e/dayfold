// Views/Entry/EntryEditorView.swift
import SwiftUI
import CoreData

private let editorBg   = Color(red: 0.04, green: 0.04, blue: 0.04)
private let editorBar  = Color(red: 0.08, green: 0.08, blue: 0.08)
private let editorSub  = Color(red: 0.45, green: 0.45, blue: 0.48)
private let editorText = Color(red: 0.93, green: 0.93, blue: 0.93)
private let accentCyan = Color(hex: "5BC8D8")

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EntryEditorViewModel
    @FocusState private var titleFocused: Bool
    @FocusState private var contentFocused: Bool
    @State private var showingSaveError = false
    @State private var showingImagePicker = false

    init(entry: Entry? = nil, context: NSManagedObjectContext, prefillDate: Date? = nil) {
        _viewModel = StateObject(wrappedValue: EntryEditorViewModel(
            context: context, entry: entry, prefillDate: prefillDate))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            editorBg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                metaBar
                editorArea
            }

            // 随键盘移动的工具栏
            keyboardToolbar
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .sheet(isPresented: $showingImagePicker) {
            MediaPicker(images: $viewModel.images)
        }
        .alert("保存失败", isPresented: $showingSaveError) {
            Button("确定", role: .cancel) {}
        }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack(spacing: 0) {
            // 日期时间
            VStack(alignment: .leading, spacing: 1) {
                Text(dateString)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(editorText)
            }

            Spacer()

            // 完成
            Button {
                saveAndDismiss()
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(accentCyan)
                        .scaleEffect(0.8)
                        .frame(width: 44, height: 32)
                } else {
                    Text("完成")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentCyan)
                        .frame(height: 32)
                }
            }
            .disabled(viewModel.isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(editorBar)
    }

    // MARK: - 元信息栏

    private var metaBar: some View {
        HStack(spacing: 6) {
            Text("日记本")
                .font(.system(size: 12))
                .foregroundColor(editorSub)

            if let place = viewModel.placeName, !place.isEmpty {
                Text("·")
                    .foregroundColor(editorSub)
                    .font(.system(size: 12))
                Text(place)
                    .font(.system(size: 12))
                    .foregroundColor(editorSub)
                    .lineLimit(1)
            }

            if let weather = viewModel.weather {
                Text("·")
                    .foregroundColor(editorSub)
                    .font(.system(size: 12))
                Image(systemName: weather.symbolName)
                    .font(.system(size: 11))
                    .foregroundColor(editorSub)
                Text("\(Int(weather.temperature))°C")
                    .font(.system(size: 12))
                    .foregroundColor(editorSub)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(editorBar)
    }

    // MARK: - 编辑区

    private var editorArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 标题
                TextField("标题（可选）", text: $viewModel.title, axis: .vertical)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(editorText)
                    .focused($titleFocused)
                    .submitLabel(.next)
                    .onSubmit { contentFocused = true }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                // 正文
                TextEditor(text: $viewModel.content)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(editorText.opacity(0.88))
                    .focused($contentFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 320)
                    .padding(.horizontal, 12)

                // 已选图片预览
                if !viewModel.images.isEmpty {
                    imagePreviewRow
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                // 键盘工具栏高度占位（避免内容被遮挡）
                Spacer().frame(height: 56)
            }
        }
        .background(editorBg)
    }

    // MARK: - 图片预览

    private var imagePreviewRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.images.enumerated()), id: \.offset) { idx, img in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 72, height: 72)
                            .clipped()
                            .cornerRadius(8)

                        Button {
                            viewModel.removeImage(at: idx)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 键盘工具栏（随键盘浮动）

    private var keyboardToolbar: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 0) {
                // 收起键盘
                toolbarButton(icon: "chevron.down") {
                    titleFocused = false
                    contentFocused = false
                }

                Spacer()

                // 图片
                toolbarButton(icon: "photo.on.rectangle") {
                    showingImagePicker = true
                }

                // 附件（占位）
                toolbarButton(icon: "paperclip") {}

                // 格式（占位）
                toolbarButton(icon: "textformat") {}
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .background(editorBar)
        }
        .keyboardAdaptive()
    }

    // MARK: - Helpers

    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(editorText.opacity(0.7))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月d日 EEEE  HH:mm"
        return fmt.string(from: Date())
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

#Preview {
    let context = CoreDataStack.shared.viewContext
    EntryEditorView(context: context)
        .environment(\.managedObjectContext, context)
}
