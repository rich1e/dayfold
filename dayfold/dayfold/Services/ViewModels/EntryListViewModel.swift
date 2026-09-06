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

    /// 全部标签,按 order 升序。
    var allTags: [Tag] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest() as! NSFetchRequest<Tag>
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    func deleteEntry(_ entry: Entry) {
        entry.moveToTrash()
        try? CoreDataStack.shared.save()
    }

    /// 批量永久删除多条,异步清理 MediaService 上的图片文件。
    /// 重复删除逻辑与单条版本一致,但一次性收集所有 filename 避免逐条起 Task。
    func permanentlyDelete(_ entries: [Entry], context: NSManagedObjectContext) {
        var filenames: [String] = []
        for entry in entries {
            for asset in entry.mediaAssetsArray {
                if let filename = asset.filename {
                    filenames.append(filename)
                }
                context.delete(asset)
            }
            if let location = entry.location { context.delete(location) }
            context.delete(entry)
        }
        if !filenames.isEmpty {
            Task { await MediaService.shared.deleteImages(filenames: filenames) }
        }
        try? CoreDataStack.shared.save()
    }

    /// 单条永久删除(批量版本的 wrapper,保留旧调用点兼容)。
    func permanentlyDelete(_ entry: Entry, context: NSManagedObjectContext) {
        permanentlyDelete([entry], context: context)
    }

    /// 批量恢复多条:直接清 deletedAt,每条回到 entry.notebook 原归属。
    func restore(_ entries: [Entry]) {
        for entry in entries {
            entry.restore()
        }
        try? CoreDataStack.shared.save()
    }

    func toggleFavorite(_ entry: Entry) {
        entry.isFavorite.toggle()
        entry.modifiedAt = Date()
        entry.needsSync = true
        try? CoreDataStack.shared.save()
    }

    func filterPredicate() -> NSPredicate? {
        var predicates: [NSPredicate] = [NSPredicate(format: "deletedAt == nil")]

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
