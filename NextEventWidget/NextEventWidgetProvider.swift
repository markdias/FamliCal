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
import AppIntents

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
@available(iOSApplicationExtension 17.0, *)
struct NextEventProvider: AppIntentTimelineProvider {
    typealias Intent = NextEventConfigurationIntent
    typealias Entry = NextEventEntry

    /// Placeholder shown while loading
    func placeholder(in context: Context) -> NextEventEntry {
        return NextEventEntry(date: Date())
    }

    /// Snapshot for widget preview
    func snapshot(for configuration: NextEventConfigurationIntent, in context: Context) async -> NextEventEntry {
        loadNextEvent(intent: configuration)
    }

    /// Main timeline generation
    func timeline(for configuration: NextEventConfigurationIntent, in context: Context) async -> Timeline<NextEventEntry> {
        let entry = loadNextEvent(intent: configuration)

        // Ask for a quicker refresh; system still enforces its own limits
        let nextRefreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextRefreshDate))
    }

    /// Load the next event for the family member with soonest upcoming event
    private func loadNextEvent(intent: NextEventConfigurationIntent? = nil) -> NextEventEntry {
        do {
            print("🔍 Widget: Starting loadNextEvent()")

            // First try to get app group container
            let appGroupID = "group.com.markdias.famli"
            guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                print("❌ Widget: App group container not accessible")
                return NextEventEntry(errorMessage: "App groups not accessible")
            }

            print("✅ Widget: App group URL: \(appGroupURL.path)")

            // Construct the database URL
            let storeURL = appGroupURL.appendingPathComponent("FamliCal.sqlite")

            // Check if database file exists
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: storeURL.path) {
                print("❌ Widget: Database file not found at \(storeURL.path)")
                if let contents = try? fileManager.contentsOfDirectory(atPath: appGroupURL.path) {
                    print("📁 Widget: App group contents: \(contents)")
                }
                return NextEventEntry(errorMessage: "Database not initialized yet")
            }

            print("✅ Widget: Database file exists at \(storeURL.path)")

            // Create a NSPersistentStoreCoordinator directly
            // Try to load from main bundle or widget bundle
            var modelURL = Bundle.main.url(forResource: "FamliCal", withExtension: "momd")

            if modelURL == nil {
                // If not found in widget bundle, try to find in app bundle
                // Widget bundle path: FamliCal.app/PlugIns/mdias.FamliCal.NextEventWidget.appex/
                // We need to go to: FamliCal.app/FamliCal.momd
                if let widgetBundlePath = Bundle.main.bundlePath as NSString? {
                    // Go up to PlugIns directory
                    let pluginsPath = widgetBundlePath.deletingLastPathComponent
                    // Go up to FamliCal.app directory
                    let appPath = (pluginsPath as NSString).deletingLastPathComponent
                    // Check for FamliCal.momd in the app bundle
                    modelURL = URL(fileURLWithPath: appPath).appendingPathComponent("FamliCal.momd")

                    if !FileManager.default.fileExists(atPath: modelURL!.path) {
                        // Also try looking in Contents/Resources for sandboxed environments
                        modelURL = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources/FamliCal.momd")
                    }
                }
            }

            guard let modelURL = modelURL, FileManager.default.fileExists(atPath: modelURL.path) else {
                let attemptedPath = Bundle.main.url(forResource: "FamliCal", withExtension: "momd")?.path ?? "none"
                let widgetBundlePath = Bundle.main.bundlePath
                print("⚠️ Widget: Data model not found.")
                print("   Attempted bundle resource: \(attemptedPath)")
                print("   Widget bundle path: \(widgetBundlePath)")
                return NextEventEntry(errorMessage: "Data model not found")
            }

            guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
                print("❌ Widget: Failed to load data model from \(modelURL.path)")
                return NextEventEntry(errorMessage: "Failed to load data model")
            }

            print("✅ Widget: Data model loaded successfully")

            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

            let storeOptions: [String: Any] = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSPersistentStoreFileProtectionKey: FileProtectionType.none,
                NSReadOnlyPersistentStoreOption: true
            ]

            // Add persistent store with options to handle file access issues
            do {
                try coordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: storeURL,
                    options: storeOptions
                )
                print("✅ Widget: Persistent store added successfully")
            } catch {
                print("❌ Widget: Failed to add persistent store: \(error.localizedDescription)")
                throw error
            }

            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator

            // Try to fetch family members
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FamilyMember")
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.resultType = .dictionaryResultType

            print("🔍 Widget: Fetching FamilyMember entities...")
            let results = try context.fetch(fetchRequest) as? [[String: Any]] ?? []

            print("📊 Widget: Fetch returned \(results.count) result(s)")

            guard !results.isEmpty else {
                print("❌ Widget: No family members found in database")
                return NextEventEntry(errorMessage: "No family members configured")
            }

            print("✅ Widget: Found \(results.count) family member(s)")

            // Get user preferences for event range
            let defaults = UserDefaults(suiteName: "group.com.markdias.famli") ?? UserDefaults.standard
            let pastDays = defaults.integer(forKey: "eventsPastDays")
            let futureDays = defaults.integer(forKey: "eventsFutureDays")

            let startDate = Calendar.current.date(byAdding: .day, value: -(pastDays > 0 ? pastDays : 90), to: Date()) ?? Date()
            let endDate = Calendar.current.date(byAdding: .day, value: futureDays > 0 ? futureDays : 180, to: Date()) ?? Date()

            // Collect all calendar IDs from family members and shared calendars
            var memberCalendarMap: [String: (memberId: UUID, name: String, colorHex: String)] = [:]
            var sharedCalendarIDs: Set<String> = []

            for result in results {
                let id = (result["id"] as? UUID) ?? UUID()
                let name = (result["name"] as? String) ?? "Unknown"
                let colorHex = (result["colorHex"] as? String) ?? "#007AFF"

                print("✅ Widget: Family member '\(name)' has color: \(colorHex)")

                // Add personal/linked calendars for this member
                if let calendarID = result["linkedCalendarID"] as? String, !calendarID.isEmpty {
                    memberCalendarMap[calendarID] = (memberId: id, name: name, colorHex: colorHex)
                }

                // Note: memberCalendarLinks relationship is handled via FamilyMemberCalendar
                // but we need to query that separately since we're using dictionary results
            }

            // Fetch FamilyMemberCalendar entities to get additional calendars and shared calendars
            let memberCalendarRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FamilyMemberCalendar")
            memberCalendarRequest.returnsObjectsAsFaults = false
            memberCalendarRequest.resultType = .dictionaryResultType

            if let memberCalendarResults = try context.fetch(memberCalendarRequest) as? [[String: Any]] {
                for result in memberCalendarResults {
                    if let calendarID = result["calendarID"] as? String, !calendarID.isEmpty {
                        // Find which family member this calendar belongs to
                        if let memberIDObj = result["familyMember"] as? NSManagedObjectID {
                            do {
                                let memberObj = try context.existingObject(with: memberIDObj)
                                let calendarColorHex = result["calendarColorHex"] as? String
                                if let name = memberObj.value(forKey: "name") as? String,
                                   let colorHex = (calendarColorHex ?? memberObj.value(forKey: "colorHex") as? String),
                                   let id = memberObj.value(forKey: "id") as? UUID {
                                    memberCalendarMap[calendarID] = (memberId: id, name: name, colorHex: colorHex)
                                }
                            } catch {
                                // Skip if member object can't be fetched
                            }
                        }
                    }
                }
            }

            // Fetch shared calendars
            let sharedCalendarRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "SharedCalendar")
            sharedCalendarRequest.returnsObjectsAsFaults = false
            sharedCalendarRequest.resultType = .dictionaryResultType

            if let sharedCalResults = try context.fetch(sharedCalendarRequest) as? [[String: Any]] {
                for result in sharedCalResults {
                    if let calendarID = result["calendarID"] as? String, !calendarID.isEmpty {
                        sharedCalendarIDs.insert(calendarID)
                        // Shared calendars should use a generic shared calendar color/name
                        // Use the first member's color or a default if not already mapped
                        if memberCalendarMap[calendarID] == nil {
                            memberCalendarMap[calendarID] = (
                                memberId: UUID(),
                                name: (result["calendarName"] as? String) ?? "Shared Calendar",
                                colorHex: (result["calendarColorHex"] as? String) ?? "#555555"
                            )
                        }
                    }
                }
            }

            guard !memberCalendarMap.isEmpty else {
                return NextEventEntry(errorMessage: "No calendars found")
            }

            let defaultMemberName = Set(memberCalendarMap.values.map { $0.name })
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .first

            let targetMemberName: String? = {
                let selectedMode = intent?.mode ?? .familyNext
                guard selectedMode == .memberNext else { return nil }
                let name = intent?.memberName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !name.isEmpty && name.lowercased() != "auto" { return name }
                return defaultMemberName
            }()

            // Fetch next events for all calendars
            let eventStore = EKEventStore()

            // Check calendar access
            let calendarAccess = EKEventStore.authorizationStatus(for: .event)
            if calendarAccess == .denied || calendarAccess == .restricted {
                return NextEventEntry(errorMessage: "Calendar access required - enable in Settings")
            }

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

            let selectedEKEvent: EKEvent?
            if let targetName = targetMemberName?.lowercased() {
                // If a shared/family event exists, show it first
                if let familyEvent = ekEvents.first(where: { sharedCalendarIDs.contains($0.calendar.calendarIdentifier) }) {
                    selectedEKEvent = familyEvent
                } else {
                    let filtered = ekEvents.filter {
                        if let calendarID = $0.calendar.calendarIdentifier as String?,
                           let info = memberCalendarMap[calendarID] {
                            return info.name.lowercased() == targetName
                        }
                        return false
                    }
                    selectedEKEvent = filtered.first
                }

                if selectedEKEvent == nil {
                    return NextEventEntry(errorMessage: "No upcoming events for \(targetName)")
                }
            } else {
                selectedEKEvent = ekEvents.first
            }

            guard let nextEKEvent = selectedEKEvent else {
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

            print("✅ Widget: Returning event for '\(member.name)' with color: \(member.colorHex)")
            return NextEventEntry(date: Date(), event: event, familyMember: member)

        } catch {
            let errorMsg = "Error: \(error.localizedDescription)"
            print("❌ Widget Error: \(errorMsg)")
            // Print more detailed error info
            let nserror = error as NSError
            print("   Domain: \(nserror.domain)")
            print("   Code: \(nserror.code)")
            return NextEventEntry(errorMessage: errorMsg)
        }
    }
}
