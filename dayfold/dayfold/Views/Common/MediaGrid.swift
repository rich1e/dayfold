// Views/Common/MediaGrid.swift
import SwiftUI

struct MediaGrid: View {
    let images: [UIImage]
    let onRemove: ((Int) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                MediaGridItem(image: image, onRemove: {
                    onRemove?(index)
                })
            }
        }
    }
}

struct MediaGridItem: View {
    let image: UIImage
    let onRemove: (() -> Void)?
    @State private var showFullscreen = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
                    .cornerRadius(8)
                    .onTapGesture {
                        showFullscreen = true
                    }

                if let onRemove = onRemove {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 24, height: 24)
                            )
                    }
                    .padding(4)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .fullScreenCover(isPresented: $showFullscreen) {
            FullscreenImageView(image: image, isPresented: $showFullscreen)
        }
    }
}

struct FullscreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}
