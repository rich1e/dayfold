// Views/Entry/EntryEditorView.swift
import SwiftUI
import CoreData

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: EntryEditorViewModel
    @State private var showingSaveError = false

    init(entry: Entry? = nil, context: NSManagedObjectContext, prefillDate: Date? = nil) {
        _viewModel = StateObject(wrappedValue: EntryEditorViewModel(context: context, entry: entry, prefillDate: prefillDate))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 标题输入
                    TextField("标题(可选)", text: $viewModel.title)
                        .font(.warmTitle)
                        .foregroundColor(.warmDark)
                        .padding()
                        .background(Color.warmPaper)

                    Divider()

                    // 位置和天气信息
                    if let placeName = viewModel.placeName {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.warmAccent)
                            Text(placeName)
                                .font(.warmCaption)
                                .foregroundColor(.warmBrown)

                            if let weather = viewModel.weather {
                                Image(systemName: weather.symbolName)
                                    .foregroundColor(.warmAccent)
                                Text("\(Int(weather.temperature))°C")
                                    .font(.warmCaption)
                                    .foregroundColor(.warmBrown)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(Color.warmCream.opacity(0.5))
                    }

                    // Markdown 编辑器
                    MarkdownEditor(
                        text: $viewModel.content,
                        wordCount: viewModel.wordCount,
                        readingTime: viewModel.readingTime
                    )
                    .frame(minHeight: 300)

                    Divider()

                    // 媒体选择器
                    VStack(alignment: .leading, spacing: 16) {
                        MediaPicker(images: $viewModel.images)

                        // 标签选择器
                        TagPicker(selectedTags: $viewModel.selectedTags)
                    }
                    .padding()
                }
            }
            .background(Color.warmPaper)
            .navigationTitle(viewModel.isNewEntry ? "新日记" : "编辑日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.warmBrown)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.isFavorite.toggle()
                    } label: {
                        Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                            .foregroundColor(.warmAccent)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveEntry()
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                                .foregroundColor(.warmAccent)
                                .fontWeight(.medium)
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.content.isEmpty)
                }
            }
        }
        .alert("保存失败", isPresented: $showingSaveError) {
            Button("确定", role: .cancel) {}
        }
    }

    private func saveEntry() {
        Task {
            let success = await viewModel.save()
            if success {
                dismiss()
            } else {
                showingSaveError = true
            }
        }
    }
}

#Preview {
    let context = CoreDataStack.shared.viewContext
    EntryEditorView(context: context)
        .environment(\.managedObjectContext, context)
}
