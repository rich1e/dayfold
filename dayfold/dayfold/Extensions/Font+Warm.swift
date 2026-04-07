// Extensions/Font+Warm.swift
import SwiftUI

extension Font {
    // 标题字体 - 宋体增强文艺感
    static let warmTitle = Font.custom("STSongti-SC-Bold", size: 24)
    static let warmHeadline = Font.custom("STSongti-SC-Regular", size: 18)

    // 正文字体 - Serif 设计提升可读性
    static let warmBody = Font.system(size: 16, weight: .regular, design: .serif)
    static let warmCaption = Font.system(size: 13, weight: .regular, design: .rounded)
    static let warmFootnote = Font.system(size: 11, weight: .regular, design: .rounded)
}
