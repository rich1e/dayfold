// ViewModels/TagManagerViewModel.swift
import Foundation
import CoreData
import SwiftUI

class TagManagerViewModel: ObservableObject {
    private let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    func createTag(name: String, color: String, icon: String) {
        let tag = Tag.create(name: name, color: color, icon: icon, in: viewContext)

        // 设置顺序为最后
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        let count = (try? viewContext.count(for: fetchRequest)) ?? 0
        tag.order = Int32(count)

        try? CoreDataStack.shared.save()
    }

    func updateTag(_ tag: Tag, name: String, color: String, icon: String) {
        tag.name = name
        tag.color = color
        tag.icon = icon
        try? CoreDataStack.shared.save()
    }

    func deleteTag(_ tag: Tag) {
        viewContext.delete(tag)
        try? CoreDataStack.shared.save()
    }

    func moveTag(from source: IndexSet, to destination: Int, in tags: [Tag]) {
        var mutableTags = tags
        mutableTags.move(fromOffsets: source, toOffset: destination)

        for (index, tag) in mutableTags.enumerated() {
            tag.order = Int32(index)
        }

        try? CoreDataStack.shared.save()
    }
}
