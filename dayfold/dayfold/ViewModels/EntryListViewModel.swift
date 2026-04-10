// ViewModels/EntryListViewModel.swift
import Foundation
import CoreData
import Combine

class EntryListViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedTags: Set<Tag> = []
    @Published var showFavoritesOnly = false

    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    func deleteEntry(_ entry: Entry) {
        // 删除关联的媒体文件
        let assetsToDelete = entry.mediaAssetsArray
        for asset in assetsToDelete {
            if let filename = asset.filename {
                Task {
                    await MediaService.shared.deleteImage(filename: filename)
                }
            }
            viewContext.delete(asset)
        }

        // 删除位置信息
        if let location = entry.location {
            viewContext.delete(location)
        }

        // 删除条目
        viewContext.delete(entry)

        // 保存
        try? CoreDataStack.shared.save()
    }

    func toggleFavorite(_ entry: Entry) {
        entry.isFavorite.toggle()
        entry.modifiedAt = Date()
        entry.needsSync = true
        try? CoreDataStack.shared.save()
    }

    func filterPredicate() -> NSPredicate? {
        var predicates: [NSPredicate] = []

        // 搜索过滤
        if !searchText.isEmpty {
            let contentPredicate = NSPredicate(format: "content CONTAINS[cd] %@", searchText)
            let titlePredicate = NSPredicate(format: "title CONTAINS[cd] %@", searchText)
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [contentPredicate, titlePredicate]))
        }

        // 收藏过滤
        if showFavoritesOnly {
            predicates.append(NSPredicate(format: "isFavorite == YES"))
        }

        // 标签过滤
        if !selectedTags.isEmpty {
            let tagPredicates = selectedTags.map { tag in
                NSPredicate(format: "ANY tags == %@", tag)
            }
            predicates.append(NSCompoundPredicate(andPredicateWithSubpredicates: tagPredicates))
        }

        return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
