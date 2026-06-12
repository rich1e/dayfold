// Views/Entry/Components/EntryCardView.swift
import SwiftUI

struct EntryCardView: View {
    let entry: Entry
    let images: [UIImage]

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日  EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: entry.createdAt ?? Date())
    }

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: entry.createdAt ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部：日期 + 天气 + 位置
            headerSection
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 14)

            Divider()
                .background(Color.warmGray.opacity(0.5))
                .padding(.horizontal, 20)

            // 正文区域
            contentSection
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, images.isEmpty ? 14 : 10)

            // 图片缩略图（最多3张）
            if !images.isEmpty {
                imageSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
            }

            Divider()
                .background(Color.warmGray.opacity(0.5))
                .padding(.horizontal, 20)

            // 底部：标签 + 水印
            footerSection
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
        }
        .frame(width: 340)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.warmDark.opacity(0.12), radius: 12, x: 0, y: 4)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dateText)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.warmBrown)

            HStack(spacing: 12) {
                Text(timeText)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.warmGray)

                if let location = entry.location {
                    if location.weatherCondition != nil {
                        HStack(spacing: 3) {
                            Image(systemName: location.weatherIcon ?? "sun.max.fill")
                                .font(.system(size: 10))
                            Text("\(Int(location.weatherTemperature))°C")
                                .font(.system(size: 11, design: .rounded))
                        }
                        .foregroundColor(.warmAccent)
                    }

                    if !location.wrappedPlaceName.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                            Text(location.wrappedPlaceName)
                                .font(.system(size: 11, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundColor(.warmAccent)
                    }
                }
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !entry.wrappedTitle.isEmpty {
                Text(entry.wrappedTitle)
                    .font(Font.custom("STSongti-SC-Bold", size: 17))
                    .foregroundColor(.warmDark)
                    .lineLimit(2)
            }

            let preview = previewContent
            if !preview.isEmpty {
                Text(preview)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(.warmDark.opacity(0.85))
                    .lineLimit(6)
                    .lineSpacing(4)
            }
        }
    }

    private var imageSection: some View {
        HStack(spacing: 6) {
            ForEach(Array(images.prefix(3).enumerated()), id: \.offset) { _, img in
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: imageWidth, height: imageWidth)
                    .clipped()
                    .cornerRadius(6)
            }
            Spacer()
        }
    }

    private var footerSection: some View {
        HStack(spacing: 0) {
            // 标签
            if !entry.tagsArray.isEmpty {
                HStack(spacing: 5) {
                    ForEach(entry.tagsArray.prefix(3), id: \.id) { tag in
                        Text("# \(tag.wrappedName)")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(tag.displayColor)
                    }
                }
            }

            Spacer()

            // 水印
            HStack(spacing: 4) {
                Image(systemName: "book.pages")
                    .font(.system(size: 9))
                Text("Dayfold")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundColor(.warmAccent.opacity(0.6))
        }
    }

    // MARK: - Helpers

    private var previewContent: String {
        // 去掉 Markdown 符号，取纯文本预览
        let raw = entry.wrappedContent
        let stripped = raw
            .replacingOccurrences(of: #"#{1,6}\s"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"^[-*]\s"#, with: "• ", options: .regularExpression)
            .replacingOccurrences(of: #"^\d+\.\s"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"> "#, with: "", options: .regularExpression)
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var imageWidth: CGFloat {
        let count = min(images.count, 3)
        let total: CGFloat = 300
        let gaps = CGFloat(count - 1) * 6
        return (total - gaps) / CGFloat(count)
    }

    private var cardBackground: some View {
        ZStack {
            Color.warmPaper
            // 轻微纸纹噪点感（渐变模拟）
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.warmCream.opacity(0.3),
                    Color.clear,
                    Color.warmCream.opacity(0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
