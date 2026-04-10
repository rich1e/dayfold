// Views/Entry/Components/TagPicker.swift
import SwiftUI

struct TagPicker: View {
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
                .background(Color.warmLight)
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
                            .background(Color.warmLight)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color.warmPaper)
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

#Preview {
    TagPicker(selectedTags: .constant([]))
        .padding()
        .background(Color.warmPaper)
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
