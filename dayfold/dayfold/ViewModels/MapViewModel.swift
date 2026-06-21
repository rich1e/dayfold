// ViewModels/MapViewModel.swift
import Foundation
import CoreData
import Combine
import CoreLocation

@MainActor
final class MapViewModel: ObservableObject {
    @Published var entries: [Entry] = []
    @Published var query: String = ""

    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
        reload()

        // 监听数据库变更，自动刷新 entries
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
    }

    var visibleEntries: [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        let lower = trimmed.lowercased()
        return entries.filter { entry in
            if entry.wrappedTitle.lowercased().contains(lower) { return true }
            if entry.wrappedContent.lowercased().contains(lower) { return true }
            if let place = entry.location?.placeName?.lowercased(),
               place.contains(lower) { return true }
            return false
        }
    }

    func reload() {
        let request: NSFetchRequest<Entry> = Entry.fetchRequest()
        request.predicate = NSPredicate(format: "deletedAt == nil AND location != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        entries = (try? context.fetch(request)) ?? []
    }
}
