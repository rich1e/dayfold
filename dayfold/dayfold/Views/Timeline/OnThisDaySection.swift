import SwiftUI
import CoreData

struct OnThisDaySection: View {
    @Environment(\.theme) private var theme
    @StateObject private var viewModel: OnThisDayViewModel

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: OnThisDayViewModel(context: context))
    }

    var body: some View {
        Group {
            if !viewModel.groups.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    summaryCard
                    ForEach(viewModel.groups) { group in
                        OnThisDayYearRow(group: group)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
        .task { viewModel.refresh() }
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.accentPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text("历史上今天你写了 \(viewModel.totalCount) 篇日记")
                    .font(.warmHeadline)
                    .foregroundColor(theme.textPrimary)
                Text("最近一篇是 \(viewModel.recentYearDiff) 年前的今天")
                    .font(.warmCaption)
                    .foregroundColor(theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .warmCard()
    }
}