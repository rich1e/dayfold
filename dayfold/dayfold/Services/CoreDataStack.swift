// Services/CoreDataStack.swift
import Foundation
import CoreData
import CloudKit

class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()

    @Published var isCloudKitAvailable = false

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "dayfold")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }

        // 启用历史跟踪(用于同步)
        description.setOption(true as NSNumber,
                            forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber,
                            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // 配置 CloudKit 容器
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.Yuqi.dayfold"
        )

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("Core Data failed to load: \(error.localizedDescription)")
            } else {
                print("Core Data loaded successfully")
                self.checkCloudKitAvailability()
            }
        }

        // 自动合并来自其他上下文的变更
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // 监听远程变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )

        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func save() throws {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func checkCloudKitAvailability() {
        CKContainer(identifier: "iCloud.com.Yuqi.dayfold")
            .accountStatus { status, error in
                DispatchQueue.main.async {
                    self.isCloudKitAvailable = (status == .available)
                    if !self.isCloudKitAvailable {
                        print("iCloud not available: \(status.rawValue)")
                    }
                }
            }
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        print("Remote change detected")
        // 视图会自动刷新,因为使用了 @FetchRequest
    }

    func createPresetTags() {
        let context = viewContext
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()

        do {
            let existingTags = try context.fetch(fetchRequest)
            guard existingTags.isEmpty else {
                print("Preset tags already exist")
                return
            }

            for (index, preset) in Tag.presetTags().enumerated() {
                let tag = Tag.create(name: preset.name, color: preset.color, icon: preset.icon, in: context)
                tag.order = Int32(index)
            }

            do {
                try save()
                print("Preset tags created successfully")
            } catch {
                print("Failed to save preset tags: \(error.localizedDescription)")
            }
        } catch {
            print("Failed to create preset tags: \(error.localizedDescription)")
        }
    }
}
