// Views/Map/MapEntryCard.swift
import SwiftUI

struct MapEntryCard: View {
    let entries: [Entry]
    var onOpen: (Entry) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽把手
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.warmGray)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 6)

            if entries.count == 1 {
                cardContent(for: entries[0])
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .onTapGesture { onOpen(entries[0]) }
            } else {
                TabView {
                    ForEach(entries, id: \.objectID) { entry in
                        cardContent(for: entry)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 22)
                            .contentShape(Rectangle())
                            .onTapGesture { onOpen(entry) }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 140)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.warmLight)
                .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: -4)
        )
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 50 { onDismiss() }
                }
        )
    }

    @ViewBuilder
    private func cardContent(for entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(formatDate(entry.createdAt))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.warmAccent)

                if let place = entry.location?.placeName, !place.isEmpty {
                    Text("·").foregroundColor(Color.warmBrown)
                    Text(place)
                        .font(.system(size: 13))
                        .foregroundColor(Color.warmBrown)
                        .lineLimit(1)
                }

                Spacer()

                if let icon = entry.location?.weatherIcon, !icon.isEmpty {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color.warmBrown)
                }
            }

            if !entry.wrappedTitle.isEmpty {
                Text(entry.wrappedTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.warmDark)
                    .lineLimit(1)
            }

            Text(entry.wrappedContent)
                .font(.system(size: 14))
                .foregroundColor(Color.warmDark.opacity(0.85))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 96)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy.MM.dd"
        return fmt.string(from: date)
    }
}
