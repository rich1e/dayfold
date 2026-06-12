// Views/Tags/TagsView.swift
import SwiftUI
import CoreData

struct TagsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: TagManagerViewModel
    @State private var editingTag: Tag?

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.order)],
        animation: .default
    )
    private var tags: FetchedResults<Tag>

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: TagManagerViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.warmPaper.ignoresSafeArea()

                if tags.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
                            TagRow(tag: tag)
                                .onTapGesture {
                                    editingTag = tag
                                }
                                .transition(.paperDrop)
                                .animation(
                                    .easeOut(duration: 0.38).delay(Double(min(index, 7)) * 0.07),
                                    value: tags.count
                                )
                        }
                        .onDelete { indexSet in
                            deleteTag(at: indexSet)
                        }
                        .onMove { source, destination in
                            viewModel.moveTag(from: source, to: destination, in: Array(tags))
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("标签管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                        .foregroundColor(.warmAccent)
                }
            }
        }
        .sheet(item: $editingTag) { tag in
            TagEditorView(tag: tag) { name, color, icon in
                viewModel.updateTag(tag, name: name, color: color, icon: icon)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "tag")
                .font(.system(size: 80))
                .foregroundColor(.warmGray)

            Text("还没有标签")
                .font(.warmHeadline)
                .foregroundColor(.warmBrown)
        }
    }

    private func deleteTag(at offsets: IndexSet) {
        offsets.forEach { index in
            let tag = tags[index]
            viewModel.deleteTag(tag)
        }
    }
}

struct TagRow: View {
    @ObservedObject var tag: Tag

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: tag.wrappedIcon)
                .font(.title2)
                .foregroundColor(tag.displayColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(tag.wrappedName)
                    .font(.warmBody)
                    .foregroundColor(.warmDark)

                Text("\(tag.entriesArray.count) 篇日记")
                    .font(.warmCaption)
                    .foregroundColor(.warmBrown.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.warmGray)
                .font(.caption)
        }
        .padding()
        .warmCard()
    }
}

#Preview {
    let context = CoreDataStack.shared.viewContext
    TagsView(context: context)
        .environment(\.managedObjectContext, context)
}
