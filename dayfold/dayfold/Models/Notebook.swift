// Models/Notebook.swift
import Foundation
import CoreData
import SwiftUI

// MARK: - 封面样式（从 HomeView 的 struct Notebook 迁出为顶层枚举）

enum NotebookCoverStyle: Int, CaseIterable {
    case chevronTeal, triangleRed, stripesBlack, leatherBrown, diagonalGray

    var spineColor: Color {
        switch self {
        case .chevronTeal:   return Color(hex: "8A8A90")
        case .triangleRed:   return Color(hex: "C04030")
        case .stripesBlack:  return Color(hex: "303035")
        case .leatherBrown:  return Color(hex: "2C1A0A")
        case .diagonalGray:  return Color(hex: "606065")
        }
    }
}

// MARK: - Notebook 实体扩展

extension Notebook {
    var wrappedName: String {
        name ?? "UNTITLED"
    }

    var coverStyle: NotebookCoverStyle {
        get { NotebookCoverStyle(rawValue: Int(coverStyleRaw)) ?? .chevronTeal }
        set { coverStyleRaw = Int32(newValue.rawValue) }
    }

    /// 本笔记本下未软删的日记，按创建时间倒序
    var entriesArray: [Entry] {
        let set = entries as? Set<Entry> ?? []
        return set
            .filter { $0.deletedAt == nil }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }

    static func create(name: String, style: NotebookCoverStyle, in context: NSManagedObjectContext) -> Notebook {
        let nb = Notebook(context: context)
        nb.id = UUID()
        nb.name = name
        nb.coverStyle = style
        nb.createdAt = Date()
        nb.sortOrder = 0
        return nb
    }

    /// 删除笔记本：本下未软删日记逐个移入回收站，再删本实体（entries 关系因 Nullify 自动解绑）。
    /// 不物理删除日记与图片；物理去留由回收站永久删除逻辑负责。
    func deleteWithEntriesToTrash(in context: NSManagedObjectContext) {
        for entry in entriesArray {
            entry.moveToTrash()
        }
        context.delete(self)
    }
}
