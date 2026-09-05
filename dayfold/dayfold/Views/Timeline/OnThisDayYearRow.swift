import SwiftUI

struct OnThisDayYearRow: View {
    @Environment(\.theme) private var theme
    let group: OnThisDayViewModel.OnThisDayYearGroup

    var body: some View {
        NavigationLink(destination: EntryDetailView(entry: group.earliest)) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("\(group.yearDiff) 年前")
                        .font(.warmCaption)
                        .foregroundColor(.warmBrown)
                    Circle()
                        .fill(theme.accentPrimary)
                        .frame(width: 8, height: 8)
                }
                .frame(width: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.warmBody)
                        .foregroundColor(.warmDark)
                        .lineLimit(1)
                    Text(group.earliest.wrappedContent)
                        .font(.warmCaption)
                        .foregroundColor(.warmBrown)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if group.count > 1 {
                    Text("+\(group.count) 篇同天")
                        .font(.warmFootnote)
                        .foregroundColor(.warmGray)
                }
            }
            .padding(16)
            .warmCard()
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var displayTitle: String {
        let t = group.earliest.wrappedTitle
        return t.isEmpty ? "无标题" : t
    }
}