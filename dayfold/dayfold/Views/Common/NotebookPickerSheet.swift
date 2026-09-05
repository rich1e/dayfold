// Views/Common/NotebookPickerSheet.swift
import SwiftUI
import CoreData

struct NotebookPickerSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSelect: (Notebook) -> Void

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Notebook.sortOrder, ascending: true),
                          NSSortDescriptor(keyPath: \Notebook.createdAt, ascending: true)],
        animation: .default
    ) private var notebooks: FetchedResults<Notebook>

    var body: some View {
        ZStack {
            theme.backgroundTertiary.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶栏
                HStack {
                    Button("取消") { dismiss() }
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Button {
                        createAndSelect()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(theme.controlInactive)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(notebooks, id: \.objectID) { nb in
                            Button {
                                onSelect(nb)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(nb.coverStyle.spineColor)
                                        .frame(width: 32, height: 32)
                                    Text(nb.wrappedName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Text("\(nb.entriesArray.count)")
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.textTertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(theme.backgroundSecondary)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func createAndSelect() {
        let nb = Notebook.create(name: "UNTITLED", style: .chevronTeal, in: context)
        nb.sortOrder = Int32(notebooks.count)
        try? CoreDataStack.shared.save()
        onSelect(nb)
        dismiss()
    }
}

#Preview {
    NotebookPickerSheet(title: "恢复到笔记本", onSelect: { _ in })
        .environment(\.managedObjectContext, CoreDataStack.shared.viewContext)
}
