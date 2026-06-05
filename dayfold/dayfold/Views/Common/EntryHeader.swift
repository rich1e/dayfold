// Views/Common/EntryHeader.swift
import SwiftUI

struct EntryHeader: View {
    @ObservedObject var entry: Entry

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 日期时间
            Text(entry.createdAt ?? Date(), formatter: dateFormatter)
                .font(.warmCaption)
                .foregroundColor(.warmBrown)

            // 位置和天气
            if let location = entry.location {
                HStack(spacing: 8) {
                    if !location.wrappedPlaceName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text(location.wrappedPlaceName)
                                .font(.warmFootnote)
                        }
                    }

                    if location.weatherCondition != nil {
                        HStack(spacing: 4) {
                            Image(systemName: location.weatherIcon ?? "sun.max.fill")
                                .font(.system(size: 10))
                            Text("\(Int(location.weatherTemperature))°C")
                                .font(.warmFootnote)
                        }
                    }
                }
                .foregroundColor(.warmAccent)
            }

            // 标签
            if !entry.tagsArray.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entry.tagsArray, id: \.id) { tag in
                            HStack(spacing: 4) {
                                Image(systemName: tag.wrappedIcon)
                                    .font(.system(size: 9))
                                Text(tag.wrappedName)
                                    .font(.system(size: 10))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tag.displayColor.opacity(0.2))
                            .foregroundColor(tag.displayColor)
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }
}
