// Views/Map/MapSearchBar.swift
import SwiftUI

struct MapSearchBar: View {
    @Environment(\.theme) private var theme
    @Binding var query: String
    var placeholder: String = "搜索地点或日记内容"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.textSecondary)

            TextField("", text: $query, prompt:
                Text(placeholder).foregroundColor(theme.textSecondary)
            )
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .foregroundColor(theme.textPrimary)
            .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(theme.backgroundSecondary)
                .overlay(Capsule().stroke(theme.dividerPrimary, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
        )
    }
}
