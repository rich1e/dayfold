// Views/StatsView.swift
import SwiftUI
import CoreData

struct StatsView: View {
    @Environment(\.theme) private var theme
    @StateObject private var viewModel: StatsViewModel
    @State private var selectedDay: DaySelection?

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(context: context))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                overviewCard
                contributionCard
                ratioCard
            }
            .padding()
        }
        .background(theme.backgroundPrimary.ignoresSafeArea())
        .onAppear { viewModel.refresh() }
    }

    // MARK: - Cards

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("总览")
                .font(.warmCaption)
                .foregroundColor(theme.textSecondary)

            HStack(spacing: 0) {
                statColumn(value: viewModel.totalEntries, label: "全部日记")
                Divider().background(theme.dividerPrimary).frame(height: 40)
                statColumn(value: viewModel.notebookCount, label: "笔记本")
            }
        }
        .warmCard()
    }

    private var contributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("活跃度")
                    .font(.warmCaption)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text(viewModel.streakLabel)
                    .font(.warmCaption)
                    .foregroundColor(theme.textSecondary)
            }

            ContributionGraphView(
                data: viewModel.visibleDailyCounts,
                range: viewModel.heatmapRange,
                selectedDay: $selectedDay
            )
            .frame(height: 110)

            Picker("范围", selection: $viewModel.heatmapRange) {
                ForEach(HeatmapRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
        .warmCard()
    }

    private var ratioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("内容比例")
                .font(.warmCaption)
                .foregroundColor(theme.textSecondary)

            HStack(spacing: 0) {
                ratioColumn(value: viewModel.mediaRatio, label: "带图片", icon: "photo")
                Divider().background(theme.dividerPrimary).frame(height: 40)
                ratioColumn(value: viewModel.locationRatio, label: "带位置", icon: "mappin")
                Divider().background(theme.dividerPrimary).frame(height: 40)
                ratioColumn(value: viewModel.tagRatio, label: "带标签", icon: "tag.fill")
            }
        }
        .warmCard()
    }

    // MARK: - Subviews

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.warmTitle)
                .foregroundColor(theme.textPrimary)
            Text(label)
                .font(.warmFootnote)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func ratioColumn(value: Double, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(theme.accentPrimary)
            Text("\(Int(value * 100))%")
                .font(.warmHeadline)
                .foregroundColor(theme.textPrimary)
            Text(label)
                .font(.warmFootnote)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
