// Models/Entry.swift
import Foundation
import CoreData

extension Entry {
    var wrappedTitle: String {
        title ?? ""
    }

    var wrappedContent: String {
        content ?? ""
    }

    var wrappedMood: String {
        mood ?? ""
    }

    var mediaAssetsArray: [MediaAsset] {
        let set = mediaAssets as? Set<MediaAsset> ?? []
        return set.sorted { $0.order < $1.order }
    }

    var tagsArray: [Tag] {
        let set = tags as? Set<Tag> ?? []
        return set.sorted { $0.order < $1.order }
    }

    var wrappedIsFavorite: Bool {
        get { isFavorite }
        set { isFavorite = newValue }
    }

    static func create(in context: NSManagedObjectContext) -> Entry {
        let entry = Entry(context: context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.modifiedAt = Date()
        entry.isFavorite = false
        entry.needsSync = true
        return entry
    }
}
