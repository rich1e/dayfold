// Views/Tags/TagEditorView.swift
import SwiftUI

struct TagEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let tag: Tag?
    let onSave: (String, String, String) -> Void

    @State private var name: String
    @State private var selectedColor: String
    @State private var selectedIcon: String

    init(tag: Tag? = nil, onSave: @escaping (String, String, String) -> Void) {
        self.tag = tag
        self.onSave = onSave
        _name = State(initialValue: tag?.wrappedName ?? "")
        _selectedColor = State(initialValue: tag?.wrappedColor ?? "DAA520")
        _selectedIcon = State(initialValue: tag?.wrappedIcon ?? "tag.fill")
    }

    private let availableColors = [
        "4A90E2", "7ED321", "F5A623", "D0021B", "BD10E0",
        "50E3C2", "FF6B6B", "8B7355", "DAA520", "9B59B6"
    ]

    private let availableIcons = [
        "tag.fill", "briefcase.fill", "house.fill", "airplane",
        "fork.knife", "figure.run", "book.fill", "gamecontroller.fill",
        "heart.fill", "star.fill", "film.fill", "music.note"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("标签名称") {
                    TextField("输入标签名称", text: $name)
                        .font(.warmBody)
                }

                Section("颜色") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(availableColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: selectedColor == color ? 4 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("图标") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(Color(hex: selectedColor))
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(Color.warmLight)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.warmAccent, lineWidth: selectedIcon == icon ? 2 : 0)
                                        )
                                )
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("预览") {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 40))
                                .foregroundColor(Color(hex: selectedColor))

                            Text(name.isEmpty ? "标签名称" : name)
                                .font(.warmBody)
                                .foregroundColor(.warmDark)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(tag == nil ? "新建标签" : "编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(name, selectedColor, selectedIcon)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
