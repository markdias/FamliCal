//
//  Persistence.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    /// Print diagnostics about the CoreData store location and contents
    static func printStoreDiagnostics() {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("⚠️ Could not find Application Support directory")
            return
        }

        let storeURL = appSupportURL.appendingPathComponent("FamliCal.sqlite")
        print("\n📊 CoreData Store Diagnostics:")
        print("   Store location: \(storeURL.path)")
        print("   Store exists: \(fileManager.fileExists(atPath: storeURL.path))")

        if let attributes = try? fileManager.attributesOfItem(atPath: storeURL.path) {
            let size = attributes[.size] as? NSNumber
            let modified = attributes[.modificationDate] as? Date
            print("   Store size: \(size?.stringValue ?? "unknown") bytes")
            print("   Last modified: \(modified?.formatted() ?? "unknown")")
        }
    }

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "FamliCal")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure app groups for widget access
            let appGroupID = "group.com.markdias.famli"

            print("🔍 Persistence: Looking for app group container '\(appGroupID)'")
            if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                let storeURL = appGroupURL.appendingPathComponent("FamliCal.sqlite")
                print("✅ Persistence: Found app group container at \(appGroupURL.path)")
                print("   Store URL: \(storeURL.path)")

                if let description = container.persistentStoreDescriptions.first {
                    description.url = storeURL
                    description.cloudKitContainerOptions = nil  // Disable CloudKit sync
                    print("✅ Persistence: Configured store URL in description")
                }
            } else {
                print("❌ Persistence: App group container not found!")
            }

            // Delete old store once to force recreation with new schema (includes Driver entity)
            Self.deleteOldPersistentStoreOnce()
        }

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("❌ CoreData Error: \(error), \(error.userInfo)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            print("✅ CoreData store loaded successfully at: \(storeDescription.url?.absoluteString ?? "unknown")")
        })

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Delete old persistent store files to ensure fresh schema
    /// Runs once per app version to handle schema changes during development
    private static func deleteOldPersistentStoreOnce() {
        let fileManager = FileManager.default
        let appGroupID = "group.com.markdias.famli"

        // Try app group container first (new location)
        if let appGroupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let markerFile = appGroupURL.appendingPathComponent(".famli_store_migrated_v1")

            // Check if we've already migrated this version
            if fileManager.fileExists(atPath: markerFile.path) {
                return // Already performed migration for this version, skip
            }

            // Construct paths for the SQLite store and its associated files in app group
            let storeURL = appGroupURL.appendingPathComponent("FamliCal.sqlite")
            let shmURL = appGroupURL.appendingPathComponent("FamliCal.sqlite-shm")
            let walURL = appGroupURL.appendingPathComponent("FamliCal.sqlite-wal")

            // Attempt to delete each file
            do {
                var deletedAny = false

                if fileManager.fileExists(atPath: storeURL.path) {
                    try fileManager.removeItem(at: storeURL)
                    print("✅ Deleted old FamliCal.sqlite store from app group")
                    deletedAny = true
                }
                if fileManager.fileExists(atPath: shmURL.path) {
                    try fileManager.removeItem(at: shmURL)
                    print("✅ Deleted FamliCal.sqlite-shm from app group")
                    deletedAny = true
                }
                if fileManager.fileExists(atPath: walURL.path) {
                    try fileManager.removeItem(at: walURL)
                    print("✅ Deleted FamliCal.sqlite-wal from app group")
                    deletedAny = true
                }

                // Always create marker file to track that migration happened for this version
                let success = fileManager.createFile(atPath: markerFile.path, contents: "migrated_v1".data(using: .utf8), attributes: nil)
                if success {
                    print("✅ Store migration completed and marked (v1)")
                } else if deletedAny {
                    print("⚠️ Store deleted but could not create marker file")
                }
            } catch {
                print("⚠️ Error managing persistent store in app group: \(error.localizedDescription)")
            }
        }
    }
}
