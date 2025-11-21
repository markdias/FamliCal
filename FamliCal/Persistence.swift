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
            let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
                .appendingPathComponent("FamliCal.sqlite")

            if let storeURL = storeURL {
                if let description = container.persistentStoreDescriptions.first {
                    description.url = storeURL
                    description.cloudKitContainerOptions = nil  // Disable CloudKit sync
                }
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

    /// Delete old persistent store files once to force CoreData to recreate with current schema
    /// This is necessary during development when the data model is updated with new entities/relationships
    private static func deleteOldPersistentStoreOnce() {
        let fileManager = FileManager.default

        // Get the Application Support directory
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("⚠️ Could not find Application Support directory")
            return
        }

        // Construct paths for the SQLite store and its associated files
        let storeURL = appSupportURL.appendingPathComponent("FamliCal.sqlite")
        let shmURL = appSupportURL.appendingPathComponent("FamliCal.sqlite-shm")
        let walURL = appSupportURL.appendingPathComponent("FamliCal.sqlite-wal")
        let markerFile = appSupportURL.appendingPathComponent(".famli_store_migrated")

        // Check if we've already migrated by looking for a marker file
        if fileManager.fileExists(atPath: markerFile.path) {
            return // Already performed migration, skip
        }

        // Attempt to delete each file
        do {
            var deletedAny = false

            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.removeItem(at: storeURL)
                print("✅ Deleted old FamliCal.sqlite store")
                deletedAny = true
            }
            if fileManager.fileExists(atPath: shmURL.path) {
                try fileManager.removeItem(at: shmURL)
                print("✅ Deleted FamliCal.sqlite-shm")
                deletedAny = true
            }
            if fileManager.fileExists(atPath: walURL.path) {
                try fileManager.removeItem(at: walURL)
                print("✅ Deleted FamliCal.sqlite-wal")
                deletedAny = true
            }

            if deletedAny {
                // Create marker file to track that migration happened
                // This file persists in the same location as the database
                let success = fileManager.createFile(atPath: markerFile.path, contents: "migrated".data(using: .utf8), attributes: nil)
                if success {
                    print("✅ Store migration completed and marked")
                }
            }
        } catch {
            print("⚠️ Error deleting old persistent store: \(error.localizedDescription)")
        }
    }
}
