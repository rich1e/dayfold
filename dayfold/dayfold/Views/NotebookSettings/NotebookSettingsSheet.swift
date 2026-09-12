// Views/NotebookSettings/NotebookSettingsSheet.swift
import SwiftUI
import PhotosUI
import CoreData
import UIKit

/// 笔记本设置 sheet。
/// 从 i 徽章点入，4 个区段：SKIN / NAME / CUSTOM SKIN / PASSWORD + 底部 DONE。
struct NotebookSettingsSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @ObservedObject var notebook: Notebook

    // MARK: - 内部状态

    @State private var photoItem: PhotosPickerItem?
    @State private var showingPasswordGate: NotebookPasswordGate.Mode?

    /// 实时同步到 `notebook.name`,这样用户在 TextField 输入时,
    /// HomeView 的标题(读 `notebook.wrappedName`)能立即响应,无需等 DONE 保存。
    /// 空字符串 → 写入 nil,fallback 显示 "UNTITLED"。
    private var nameBinding: Binding<String> {
        Binding(
            get: { notebook.name ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                notebook.name = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    skinSection
                    nameSection
                    customSkinSection
                    passwordSection
                    Spacer(minLength: 80)   // 给底部 DONE 留空间
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            VStack {
                Spacer()
                doneButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .onChange(of: photoItem) { newItem in
            guard let newItem else { return }
            Task {
                await loadAndApplyCustomSkin(from: newItem)
            }
        }
        .sheet(item: $showingPasswordGate) { mode in
            NavigationStack {
                NotebookPasswordGate(mode: mode, notebook: notebook) {
                    showingPasswordGate = nil
                }
            }
            .environment(\.theme, theme)
            .interactiveDismissDisabled(mode == .verify)
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack {
            Text("ALBUM SETTING")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.textPrimary)
                .tracking(2)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - SKIN

    private var skinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("SKIN")
            SkinPicker(notebook: notebook)
                .frame(height: 95)
        }
    }

    // MARK: - NAME

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("NAME")
            TextField("UNTITLED", text: nameBinding)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - CUSTOM SKIN

    private var customSkinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("CUSTOM SKIN")
            HStack(spacing: 16) {
                customSkinPreview
                    .frame(width: 140, height: 198)

                HStack(spacing: 16) {
                    addButton
                    deleteButton
                        .opacity(notebook.customSkinImage == nil ? 0.4 : 1)
                        .disabled(notebook.customSkinImage == nil)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var customSkinPreview: some View {
        if let img = notebook.customSkinImage {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.backgroundElevated)
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(theme.textTertiary)
                )
        }
    }

    private var addButton: some View {
        PhotosPicker(
            selection: $photoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Circle()
                .fill(theme.backgroundElevated)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                )
        }
    }

    private var deleteButton: some View {
        Button {
            notebook.clearCustomSkin()
        } label: {
            Circle()
                .fill(theme.backgroundElevated)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - PASSWORD

    private var passwordSection: some View {
        HStack {
            sectionTitle("PASSWORD")
            Spacer()
            Toggle("", isOn: passwordToggleBinding)
                .labelsHidden()
                .tint(theme.accentPrimary)
        }
    }

    // MARK: - DONE

    private var doneButton: some View {
        Button {
            try? CoreDataStack.shared.save()
            dismiss()
        } label: {
            Text("DONE")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(theme.textOnAccent)
                .tracking(2)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(theme.accentPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 工具

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(theme.accentPrimary)
            .tracking(1.5)
    }

    /// 从 PhotosPickerItem 加载图片并写入 CustomSkinStorage。
    /// 失败时保留旧 skin 不变（用户已有的设置不丢）。
    private func loadAndApplyCustomSkin(from item: PhotosPickerItem) async {
        defer { photoItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                return
            }
            try await notebook.setCustomSkin(image)
            try? CoreDataStack.shared.save()
        } catch {
            // 写文件失败保留旧 skin,避免用户操作丢失数据
            #if DEBUG
            print("Custom skin load failed: \(error)")
            #endif
        }
    }

    // MARK: - Bindings

    /// Toggle 用 binding 包装：
    /// - 开关 ON 且当前未设密码 → 弹 .set
    /// - 开关 OFF 且当前已设密码 → 弹 .verifyThenClear
    /// - 其他情况直接同步字段
    private var passwordToggleBinding: Binding<Bool> {
        Binding(
            get: { notebook.isPasswordEnabled },
            set: { newValue in
                if newValue && !notebook.isPasswordEnabled {
                    showingPasswordGate = .set
                } else if !newValue && notebook.isPasswordEnabled {
                    showingPasswordGate = .verifyThenClear
                }
                // 实际写入由 gate 回调完成后做,这里不再直接写字段
            }
        )
    }
}

// MARK: - Mode Identifiable

extension NotebookPasswordGate.Mode: Identifiable {
    var id: String {
        switch self {
        case .verify:           return "verify"
        case .set:              return "set"
        case .verifyThenClear:  return "verifyThenClear"
        }
    }
}
