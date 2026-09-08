// Views/Stats/DaySelection.swift
import Foundation

/// 单格选中态包装：用于 `.popover(item:)` 绑定
struct DaySelection: Identifiable {
    let id = UUID()
    let day: Date
    let count: Int
}
