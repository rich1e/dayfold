// Views/Entry/Components/MediaPicker.swift
import SwiftUI
import PhotosUI

struct MediaPicker: View {
    @Binding var images: [UIImage]
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 照片网格
            if !images.isEmpty {
                MediaGrid(images: images) { index in
                    images.remove(at: index)
                }
                .padding(.vertical, 8)
            }

            // 添加照片按钮
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                    Text("添加照片")
                        .font(.warmBody)
                }
                .foregroundColor(.warmAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.warmLight)
                .cornerRadius(12)
            }
            .onChange(of: selectedItems) { oldValue, newValue in
                loadPhotos(from: newValue)
            }
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            images.append(image)
                        }
                    }
                case .failure(let error):
                    print("Failed to load image: \(error)")
                }
            }
        }
    }
}

#Preview {
    MediaPicker(images: .constant([]))
        .padding()
        .background(Color.warmPaper)
}
