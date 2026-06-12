// Views/Entry/EntryCardPreviewSheet.swift
import SwiftUI

struct EntryCardPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: Entry
    let images: [UIImage]

    @State private var isSaving = false
    @State private var saveResult: SaveResult? = nil
    @State private var shareImage: UIImage? = nil
    @State private var showingShareSheet = false

    enum SaveResult {
        case success, failure, noPermission
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 24) {
                    // 卡片预览
                    ScrollView {
                        EntryCardView(entry: entry, images: images)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }

                    // 操作按钮
                    VStack(spacing: 12) {
                        Button {
                            Task { await saveCard() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: "photo.badge.arrow.down")
                                }
                                Text(isSaving ? "保存中..." : "保存到相册")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.warmAccent)
                            .cornerRadius(14)
                        }
                        .disabled(isSaving)

                        Button {
                            shareCard()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("分享")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.warmAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.warmAccent.opacity(0.1))
                            .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("卡片预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(.warmAccent)
                }
            }
            .alert(alertTitle, isPresented: .constant(saveResult != nil)) {
                Button("确定") { saveResult = nil }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let img = shareImage {
                    ShareSheet(items: [img])
                }
            }
        }
    }

    // MARK: - Actions

    private func saveCard() async {
        isSaving = true
        defer { isSaving = false }

        guard let image = CardExporter.render(
            EntryCardView(entry: entry, images: images)
        ) else {
            saveResult = .failure
            return
        }

        let success = await CardExporter.saveToPhotos(image)
        saveResult = success ? .success : .noPermission
    }

    private func shareCard() {
        guard let image = CardExporter.render(
            EntryCardView(entry: entry, images: images)
        ) else { return }
        shareImage = image
        showingShareSheet = true
    }

    // MARK: - Alert text

    private var alertTitle: String {
        switch saveResult {
        case .success: return "已保存"
        case .failure: return "保存失败"
        case .noPermission: return "无相册权限"
        case nil: return ""
        }
    }

    private var alertMessage: String {
        switch saveResult {
        case .success: return "卡片已保存到系统相册"
        case .failure: return "生成图片时出错，请重试"
        case .noPermission: return "请在「设置 → 隐私 → 照片」中允许 Dayfold 访问相册"
        case nil: return ""
        }
    }
}

// MARK: - ShareSheet wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
