// Views/Entry/Components/TagPicker.swift
import SwiftUI

struct TagPicker: View {
    @Environment(\.theme) private var theme
    @Binding var selectedTags: [Tag]
    @State private var showingTagSelector = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 已选标签
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedTags, id: \.id) { tag in
                            TagChip(tag: tag, isSelected: true) {
                                removeTag(tag)
                            }
                        }
                    }
                }
            }

            // 添加标签按钮
            Button {
                showingTagSelector = true
            } label: {
                HStack {
                    Image(systemName: "tag")
                    Text("添加标签")
                        .font(.warmBody)
                }
                .foregroundColor(.warmAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(theme.backgroundSecondary)
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingTagSelector) {
            TagSelectorSheet(selectedTags: $selectedTags)
        }
    }

    private func removeTag(_ tag: Tag) {
        selectedTags.removeAll { $0.id == tag.id }
    }
}

struct TagChip: View {
    @Environment(\.theme) private var theme
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: tag.wrappedIcon)
                    .font(.system(size: 12))

                Text(tag.wrappedName)
                    .font(.warmCaption)

                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tag.displayColor.opacity(0.2))
            .foregroundColor(tag.displayColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tag.displayColor, lineWidth: isSelected ? 1.5 : 0)
            )
        }
    }
}

struct TagSelectorSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedTags: [Tag]

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.order)],
        animation: .default
    )
    private var allTags: FetchedResults<Tag>

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(allTags, id: \.id) { tag in
                        let isSelected = selectedTags.contains(where: { $0.id == tag.id })

                        Button {
                            toggleTag(tag)
                        } label: {
                            HStack {
                                Image(systemName: tag.wrappedIcon)
                                    .foregroundColor(tag.displayColor)

                                Text(tag.wrappedName)
                                    .font(.warmBody)
                                    .foregroundColor(.warmDark)

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(tag.displayColor)
                                }
                            }
                            .padding()
                            .background(theme.backgroundSecondary)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(theme.backgroundPrimary)
            .navigationTitle("选择标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.warmAccent)
                }
            }
        }
    }

    private func toggleTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }
}

// MARK: - 已选标签 chip 行（独立视图，复用 TagChip）

struct SelectedTagsRow: View {
    @Environment(\.theme) private var theme
    let tags: [Tag]
    let onRemove: (Tag) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.id) { tag in
                    TagChip(tag: tag, isSelected: true) {
                        onRemove(tag)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    SelectedTagsRow(
        tags: [],
        onRemove: { _ in }
    )
    .padding()
    .background(Color.warmPaper)
}
