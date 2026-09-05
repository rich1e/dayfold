// Views/Settings/ThemeView.swift
import SwiftUI

/// 主题切换页。点抽屉 Preferences → Theme 进入。
/// 3 个主题选项用 RadioButton（不是原点），每个选项旁显示主题预览色块（bg + accent 左下角）。
struct ThemeView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 主题预览卡片：每个主题一行，左侧预览色块，右侧名称 + 副标题
                VStack(spacing: 0) {
                    ForEach(ThemeID.allCases) { tid in
                        ThemeRow(
                            tid: tid,
                            isSelected: ThemeManager.shared.id == tid
                        ) {
                            ThemeManager.shared.id = tid
                        }
                        if tid != ThemeID.allCases.last {
                            Divider()
                                .background(theme.dividerSubtle)
                                .padding(.leading, 64)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(theme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
        }
        .background(theme.backgroundPrimary.ignoresSafeArea())
    }
}

/// 单个主题行：左 32×32 预览色块（bg + 左下 accent 角标）+ 中主题名 + 右选中态
private struct ThemeRow: View {
    @Environment(\.theme) private var theme
    let tid: ThemeID
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ThemeSwatch(tid: tid)
                    .frame(width: 36, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(tid.displayName)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.accentPrimary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// 主题预览色块：整块 = 该主题 backgroundPrimary；左下角小方块 = accentPrimary
private struct ThemeSwatch: View {
    let tid: ThemeID

    var body: some View {
        let t = ThemeManager.theme(for: tid)
        ZStack(alignment: .bottomLeading) {
            t.backgroundPrimary
            RoundedRectangle(cornerRadius: 1.5)
                .fill(t.accentPrimary)
                .frame(width: 12, height: 12)
                .padding(3)
        }
    }
}
