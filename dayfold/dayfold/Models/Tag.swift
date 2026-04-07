// Models/Tag.swift
import Foundation
import CoreData
import SwiftUI

extension Tag {
    var wrappedName: String {
        name ?? ""
    }

    var wrappedColor: String {
        color ?? "DAA520"
    }

    var wrappedIcon: String {
        icon ?? "tag.fill"
    }

    var displayColor: Color {
        Color(hex: wrappedColor)
    }

    var entriesArray: [Entry] {
        let set = entries as? Set<Entry> ?? []
        return set.sorted { $0.createdAt ?? Date() > $1.createdAt ?? Date() }
    }

    static func create(name: String, color: String, icon: String, in context: NSManagedObjectContext) -> Tag {
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        tag.color = color
        tag.icon = icon
        tag.order = 0
        return tag
    }

    static func presetTags() -> [(name: String, color: String, icon: String)] {
        [
            ("工作", "4A90E2", "briefcase.fill"),
            ("生活", "7ED321", "house.fill"),
            ("旅行", "F5A623", "airplane"),
            ("美食", "D0021B", "fork.knife"),
            ("运动", "BD10E0", "figure.run"),
            ("学习", "50E3C2", "book.fill"),
            ("娱乐", "FF6B6B", "gamecontroller.fill")
        ]
    }
}
