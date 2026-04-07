// Models/MediaAsset.swift
import Foundation
import CoreData

enum MediaType: String {
    case photo = "photo"
    case video = "video"
}

extension MediaAsset {
    var mediaType: MediaType {
        MediaType(rawValue: type ?? "photo") ?? .photo
    }

    var wrappedFilename: String {
        filename ?? ""
    }

    static func create(type: MediaType, filename: String, in context: NSManagedObjectContext) -> MediaAsset {
        let asset = MediaAsset(context: context)
        asset.id = UUID()
        asset.type = type.rawValue
        asset.filename = filename
        asset.order = 0
        return asset
    }
}
