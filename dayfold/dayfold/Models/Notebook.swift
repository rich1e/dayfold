// Models/Notebook.swift
import Foundation
import CoreData
import SwiftUI
import UIKit

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

    /// 是否设了密码。hash + salt 才是真相；`hasPassword` Core Data 字段是 hint,
    /// 仅在 set/clear 阶段与之同步更新，便于 UI 快速判断。
    /// 注意:Core Data 自动 codegen 已经生成了 `hasPassword` get-only 属性，
    /// 这里扩展一个 `isPasswordEnabled` 别名供业务层使用，避免冲突。
    var isPasswordEnabled: Bool {
        (passwordHash?.isEmpty == false) && (passwordSalt?.isEmpty == false)
    }

    /// 当前 Custom Skin 图片（若存在）。从 Documents/Skins/<id>.jpg 同步读取。
    var customSkinImage: UIImage? {
        guard let id, let filename = customSkinFilename, !filename.isEmpty else { return nil }
        return CustomSkinStorage.shared.loadSkin(filename: filename, notebookID: id)
    }

    /// 上传自定义封面：写入 Documents/Skins/<id>.jpg，写 Core Data。
    /// 文件名固定为 `<notebookID>.jpg`，与 `customSkinImage` 读取路径对齐。
    func setCustomSkin(_ image: UIImage) async throws {
        guard let id else { throw NotebookError.missingID }
        let filename = "\(id.uuidString).jpg"
        try await CustomSkinStorage.shared.saveSkin(
            image: image,
            filename: filename,
            notebookID: id
        )
        customSkinFilename = filename
    }

    /// 移除自定义封面：删文件 + 清 Core Data 字段。
    func clearCustomSkin() {
        guard let id, let filename = customSkinFilename else {
            customSkinFilename = nil
            return
        }
        CustomSkinStorage.shared.deleteSkin(filename: filename, notebookID: id)
        customSkinFilename = nil
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
    /// Custom Skin 文件同步清理。
    func deleteWithEntriesToTrash(in context: NSManagedObjectContext) {
        clearCustomSkin()
        for entry in entriesArray {
            entry.moveToTrash()
        }
        context.delete(self)
    }
}

// MARK: - Errors

enum NotebookError: LocalizedError {
    case missingID

    var errorDescription: String? {
        switch self {
        case .missingID: return "Notebook ID 缺失，无法保存封面"
        }
    }
}
