//
//  NextEventWidgetProvider.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import WidgetKit
import SwiftUI
import CoreData
import EventKit

/// Timeline entry for the widget
struct NextEventEntry: TimelineEntry {
    let date: Date
    let event: WidgetEventData?
    let familyMember: FamilyMemberData?
    let errorMessage: String?

    /// Initialize with success data
    init(date: Date = Date(), event: WidgetEventData, familyMember: FamilyMemberData) {
        self.date = date
        self.event = event
        self.familyMember = familyMember
        self.errorMessage = nil
    }

    /// Initialize with error state
    init(date: Date = Date(), errorMessage: String) {
        self.date = date
        self.event = nil
        self.familyMember = nil
        self.errorMessage = errorMessage
    }

    /// Initialize with placeholder
    init(date: Date = Date()) {
        self.date = date
        self.event = nil
        self.familyMember = nil
        self.errorMessage = nil
    }
}

/// Simple family member data for widget (no CoreData dependency)
struct FamilyMemberData: Codable {
    let id: UUID
    let name: String
    let colorHex: String
}

/// Event data simplified for widget display
struct WidgetEventData: Codable {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let colorHex: String
}

/// Timeline provider for next event widget
struct NextEventProvider: TimelineProvider {
    typealias Entry = NextEventEntry

    /// Placeholder shown while loading
    func placeholder(in context: Context) -> NextEventEntry {
        return NextEventEntry(date: Date())
    }

    /// Snapshot for widget preview
    func getSnapshot(in context: Context, completion: @escaping (NextEventEntry) -> Void) {
        let entry = loadNextEvent()
        completion(entry)
    }

    /// Main timeline generation
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextEventEntry>) -> Void) {
        let entry = loadNextEvent()

        // Widget updates every 15 minutes (system limitation)
        let nextRefreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextRefreshDate))

        completion(timeline)
    }

    /// Load the next event for the family member with soonest upcoming event
    private func loadNextEvent() -> NextEventEntry {
        do {
            // First try to get app group container
            let appGroupID = "group.com.markdias.famli"
            guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                return NextEventEntry(errorMessage: "App groups not accessible")
            }

            // Construct the database URL
            let storeURL = appGroupURL.appendingPathComponent("FamliCal.sqlite")

            // Check if database file exists
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: storeURL.path) {
                print("⚠️ Widget: Database file not found at \(storeURL.path)")
                return NextEventEntry(errorMessage: "Database not initialized yet")
            }

            // Create a NSPersistentStoreCoordinator directly
            // Try to load from main bundle or widget bundle
            var modelURL = Bundle.main.url(forResource: "FamliCal", withExtension: "momd")

            if modelURL == nil {
                // If not found in widget bundle, try common bundle paths
                if let path = Bundle.main.bundlePath as NSString? {
                    let parentPath = (path.deletingLastPathComponent as NSString).deletingLastPathComponent
                    modelURL = URL(fileURLWithPath: parentPath).appendingPathComponent("FamliCal.app/FamliCal.momd")
                }
            }

            guard let modelURL = modelURL, FileManager.default.fileExists(atPath: modelURL.path) else {
                print("⚠️ Widget: Data model not found. Tried: \(Bundle.main.url(forResource: "FamliCal", withExtension: "momd")?.path ?? "unknown")")
                return NextEventEntry(errorMessage: "Data model not found")
            }

            guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
                return NextEventEntry(errorMessage: "Failed to load data model")
            }

            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

            // Add persistent store with options to handle file access issues
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: [NSReadOnlyPersistentStoreOption: true]  // Widget should only read
            )

            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator

            // Try to fetch family members
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FamilyMember")
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.resultType = .dictionaryResultType

            let results = try context.fetch(fetchRequest) as? [[String: Any]] ?? []

            guard !results.isEmpty else {
                return NextEventEntry(errorMessage: "No family members configured")
            }

            // Get user preferences for event range
            let defaults = UserDefaults(suiteName: "group.com.markdias.famli") ?? UserDefaults.standard
            let pastDays = defaults.integer(forKey: "eventsPastDays")
            let futureDays = defaults.integer(forKey: "eventsFutureDays")

            let startDate = Calendar.current.date(byAdding: .day, value: -(pastDays > 0 ? pastDays : 90), to: Date()) ?? Date()
            let endDate = Calendar.current.date(byAdding: .day, value: futureDays > 0 ? futureDays : 180, to: Date()) ?? Date()

            // Collect all calendar IDs from family members
            var memberCalendarMap: [String: (memberId: UUID, name: String, colorHex: String)] = [:]

            for result in results {
                if let calendarID = result["linkedCalendarID"] as? String, !calendarID.isEmpty {
                    let id = (result["id"] as? UUID) ?? UUID()
                    let name = (result["name"] as? String) ?? "Unknown"
                    let colorHex = (result["colorHex"] as? String) ?? "#007AFF"
                    memberCalendarMap[calendarID] = (memberId: id, name: name, colorHex: colorHex)
                }
            }

            guard !memberCalendarMap.isEmpty else {
                return NextEventEntry(errorMessage: "No calendars found")
            }

            // Fetch next events for all calendars
            let eventStore = EKEventStore()
            let calendarIDs = Array(memberCalendarMap.keys)
            let calendars = eventStore.calendars(for: .event)
                .filter { calendarIDs.contains($0.calendarIdentifier) }

            guard !calendars.isEmpty else {
                return NextEventEntry(errorMessage: "No calendars found")
            }

            let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
            let ekEvents = eventStore.events(matching: predicate)
                .filter { !$0.isAllDay }
                .filter { $0.endDate > Date() }
                .sorted { $0.startDate < $1.startDate }

            guard let nextEKEvent = ekEvents.first else {
                return NextEventEntry(errorMessage: "No upcoming events")
            }

            // Find which family member has this event
            guard let calendarID = nextEKEvent.calendar.calendarIdentifier as String?,
                  let memberInfo = memberCalendarMap[calendarID] else {
                return NextEventEntry(errorMessage: "Could not identify member")
            }

            let member = FamilyMemberData(
                id: memberInfo.memberId,
                name: memberInfo.name,
                colorHex: memberInfo.colorHex
            )

            let event = WidgetEventData(
                title: nextEKEvent.title ?? "Event",
                startDate: nextEKEvent.startDate,
                endDate: nextEKEvent.endDate,
                location: nextEKEvent.location,
                colorHex: memberInfo.colorHex
            )

            return NextEventEntry(date: Date(), event: event, familyMember: member)

        } catch {
            let errorMsg = "Error: \(error.localizedDescription)"
            print("❌ Widget Error: \(errorMsg)")
            // Print more detailed error info
            if let nserror = error as? NSError {
                print("   Domain: \(nserror.domain)")
                print("   Code: \(nserror.code)")
                print("   UserInfo: \(nserror.userInfo)")
            }
            return NextEventEntry(errorMessage: errorMsg)
        }
    }
}
