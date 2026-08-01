// Views/StatsView.swift
import SwiftUI
import CoreData

struct StatsView: View {
    @StateObject private var viewModel: StatsViewModel

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(context: context))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                streakCard
                ratioCard
                tagDistributionCard
            }
            .padding()
        }
        .background(Color.warmPaper.ignoresSafeArea())
        .onAppear { viewModel.refresh() }
    }

    // MARK: - Cards

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("总览")
                .font(.warmCaption)
                .foregroundColor(Color.warmBrown)

            HStack(spacing: 0) {
                statColumn(value: viewModel.totalEntries, label: "全部")
                Divider().background(Color.warmCream).frame(height: 40)
                statColumn(value: viewModel.monthEntries, label: "本月")
                Divider().background(Color.warmCream).frame(height: 40)
                statColumn(value: viewModel.yearEntries, label: "今年")
            }
        }
        .warmCard()
    }

    private var streakCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 36))
                .foregroundColor(Color.warmAccent)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(viewModel.currentStreak)")
                        .font(.warmTitle)
                        .foregroundColor(Color.warmDark)
                    Text("天")
                        .font(.warmHeadline)
                        .foregroundColor(Color.warmBrown)
                }
                Text("连续记录")
                    .font(.warmCaption)
                    .foregroundColor(Color.warmBrown)
            }

            Spacer()
        }
        .warmCard()
    }

    private var ratioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("内容比例")
                .font(.warmCaption)
                .foregroundColor(Color.warmBrown)

            HStack(spacing: 0) {
                ratioColumn(value: viewModel.mediaRatio, label: "带图片", icon: "photo")
                Divider().background(Color.warmCream).frame(height: 40)
                ratioColumn(value: viewModel.locationRatio, label: "带位置", icon: "mappin")
            }
        }
        .warmCard()
    }

    private var tagDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("标签分布")
                .font(.warmCaption)
                .foregroundColor(Color.warmBrown)

            if viewModel.tagDistribution.isEmpty {
                Text("暂无标签")
                    .font(.warmFootnote)
                    .foregroundColor(Color.warmBrown)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.tagDistribution) { stat in
                        tagRow(stat: stat)
                    }
                }
            }
        }
        .warmCard()
    }

    // MARK: - Subviews

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.warmTitle)
                .foregroundColor(Color.warmDark)
            Text(label)
                .font(.warmFootnote)
                .foregroundColor(Color.warmBrown)
        }
        .frame(maxWidth: .infinity)
    }

    private func ratioColumn(value: Double, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color.warmAccent)
            Text("\(Int(value * 100))%")
                .font(.warmHeadline)
                .foregroundColor(Color.warmDark)
            Text(label)
                .font(.warmFootnote)
                .foregroundColor(Color.warmBrown)
        }
        .frame(maxWidth: .infinity)
    }

    private func tagRow(stat: StatsViewModel.TagStat) -> some View {
        let maxCount = viewModel.tagDistribution.first?.count ?? 1
        let fraction = maxCount == 0 ? 0 : Double(stat.count) / Double(maxCount)
        return HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: stat.tag.wrappedIcon)
                    .font(.system(size: 12))
                    .foregroundColor(stat.tag.displayColor)
                Text(stat.tag.wrappedName)
                    .font(.warmCaption)
                    .foregroundColor(Color.warmDark)
                    .lineLimit(1)
            }
            .frame(minWidth: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.warmGray)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(stat.tag.displayColor)
                        .frame(width: geo.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(stat.count)")
                .font(.warmCaption)
                .foregroundColor(Color.warmBrown)
                .frame(minWidth: 24, alignment: .trailing)
        }
    }
}