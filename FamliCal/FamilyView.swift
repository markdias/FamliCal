//
//  FamilyView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import EventKit
import Combine

struct FamilyView: View {
    var onSearchRequested: (() -> Void)? = nil
    var onAddEventRequested: (() -> Void)? = nil
    var onChangeViewRequested: (() -> Void)? = nil
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("eventsPerPerson") private var eventsPerPerson: Int = 3
    @AppStorage("spotlightEventsPerPerson") private var spotlightEventsPerPerson: Int = 5
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval: Int = 5

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @FetchRequest(
        entity: FamilyMemberCalendar.entity(),
        sortDescriptors: []
    )
    private var memberCalendarLinks: FetchedResults<FamilyMemberCalendar>

    @State private var isLoadingEvents = false
    @State private var memberEvents: [MemberEventGroup] = []
    @State private var eventsTask: Task<Void, Never>? = nil
    @State private var selectedEvent: UpcomingCalendarEvent? = nil
    @State private var showingEventDetail = false
    @State private var spotlightMemberName: String? = nil
    @State private var eventStore = EKEventStore()
    @State private var refreshTimer: Timer? = nil
    @State private var currentTime = Date()
    @State private var showingSettings = false
    @State private var showingSearch = false
    @State private var showingAddEvent = false
    @State private var availableCalendars: [EKCalendar] = []

    private let calendar = Calendar.current

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomLeading) {
                mainScrollView
                    .navigationBarHidden(true)

                floatingControls
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .sheet(isPresented: $showingEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event)
            }
        }
        .sheet(isPresented: Binding(
            get: { spotlightMemberName != nil },
            set: { if !$0 { spotlightMemberName = nil } }
        )) {
            if let memberName = spotlightMemberName,
               let member = familyMembers.first(where: { $0.name == memberName }) {
                NavigationView {
                    SpotlightView(member: member)
                        .environment(\.managedObjectContext, viewContext)
                        .onAppear {
                            UserDefaults.standard.set(spotlightEventsPerPerson, forKey: "spotlightEventsPerPerson")
                        }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingSearch) {
            EventSearchView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView()
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Child Views

    private var mainScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                contentView
            }
            .padding(.horizontal, 16)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await reloadEvents()
        }
        .onAppear(perform: setupView)
        .onChange(of: familyMembers.count) { _, _ in loadNextEvents() }
        .onChange(of: memberCalendarLinks.count) { _, _ in loadNextEvents() }
        .onChange(of: eventsPerPerson) { _, _ in loadNextEvents() }
        .onChange(of: autoRefreshInterval) { _, _ in startRefreshTimer() }
        .onChange(of: currentTime) { _, _ in /* Trigger re-render for status updates */ }
        .onDisappear(perform: cleanupView)
    }

    private var floatingControls: some View {
        HStack(alignment: .center) {
            controlStack

            Spacer()

            addEventButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private var controlStack: some View {
        HStack(spacing: 12) {
            ControlCircleButton(imageName: "gearshape.fill") {
                showingSettings = true
            }
            .accessibilityLabel("Open settings")

            ControlCircleButton(imageName: "magnifyingglass") {
                if let action = onSearchRequested {
                    action()
                } else {
                    showingSearch = true
                }
            }
            .accessibilityLabel("Search events")

            ControlCircleButton(imageName: "calendar") {
                onChangeViewRequested?()
            }
            .accessibilityLabel("Switch view")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).opacity(0.95))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }

    private var addEventButton: some View {
        Button(action: {
            if let action = onAddEventRequested {
                action()
            } else {
                showingAddEvent = true
            }
        }) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
        }
        .accessibilityLabel("Add event")
    }

    private struct ControlCircleButton: View {
        let imageName: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: imageName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoadingEvents {
            loadingView
        } else if memberEvents.isEmpty {
            emptyStateView
        } else {
            eventsListView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.blue)

            Text("Fetching upcoming events...")
                .font(.system(size: 15))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No upcoming events")
                .font(.system(size: 16, weight: .semibold))

            Text("Link family calendars in Settings to see everyone's next plans.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var eventsListView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // MARK: Next Events Section
            VStack(alignment: .leading, spacing: 16) {

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach($memberEvents) { $memberGroup in
                        if let nextEvent = memberGroup.nextEvent,
                           !nextEvent.isAllDay,
                           nextEvent.timeRange != nil,
                           nextEvent.endDate > Date() {
                            Button(action: {
                                spotlightMemberName = memberGroup.memberName
                            }) {
                                nextEventCard(for: memberGroup, event: nextEvent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // MARK: Upcoming Events Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Upcoming Events")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(memberEvents) { memberGroup in
                        if !memberGroup.upcomingEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                // Member name header
                                Text(memberGroup.memberName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)

                                // Events for this member (limited by eventsPerPerson, only future events)
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(memberGroup.upcomingEvents, id: \.id) { groupedEvent in
                                        Button(action: {
                                            selectedEvent = UpcomingCalendarEvent(
                                                id: groupedEvent.eventIdentifier,
                                                title: groupedEvent.title,
                                                location: groupedEvent.location,
                                                startDate: groupedEvent.startDate,
                                                endDate: groupedEvent.endDate,
                                                calendarID: groupedEvent.calendarID,
                                                calendarColor: groupedEvent.memberColor,
                                                calendarTitle: groupedEvent.calendarTitle,
                                                hasRecurrence: groupedEvent.hasRecurrence,
                                                recurrenceRule: nil,
                                                isAllDay: groupedEvent.isAllDay
                                            )
                                            showingEventDetail = true
                                        }) {
                                            eventCard(groupedEvent)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            let event = UpcomingCalendarEvent(
                                                id: groupedEvent.eventIdentifier,
                                                title: groupedEvent.title,
                                                location: groupedEvent.location,
                                                startDate: groupedEvent.startDate,
                                                endDate: groupedEvent.endDate,
                                                calendarID: groupedEvent.calendarID,
                                                calendarColor: groupedEvent.memberColor,
                                                calendarTitle: groupedEvent.calendarTitle,
                                                hasRecurrence: groupedEvent.hasRecurrence,
                                                recurrenceRule: nil,
                                                isAllDay: groupedEvent.isAllDay
                                            )

                                            Button(action: { duplicateEvent(event) }) {
                                                Label("Duplicate", systemImage: "doc.on.doc")
                                            }

                                            // Move to calendar
                                            Menu {
                                                ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                                    Button(action: {
                                                        moveEventToCalendar(event, calendarID: calendar.calendarIdentifier)
                                                    }) {
                                                        HStack {
                                                            Text(calendar.title)
                                                            if calendar.calendarIdentifier == event.calendarID {
                                                                Image(systemName: "checkmark")
                                                            }
                                                        }
                                                    }
                                                }
                                            } label: {
                                                Label("Move to Calendar", systemImage: "calendar.badge.plus")
                                            }

                                            Divider()

                                            // Delete action
                                            if groupedEvent.hasRecurrence {
                                                Menu {
                                                    Button(action: { deleteEvent(event, span: .thisEvent) }) {
                                                        Label("Delete This Event", systemImage: "trash")
                                                    }
                                                    Button(role: .destructive, action: { deleteEvent(event, span: .futureEvents) }) {
                                                        Label("Delete This & Future Events", systemImage: "trash")
                                                    }
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            } else {
                                                Button(role: .destructive, action: { deleteEvent(event, span: .thisEvent) }) {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func nextEventCard(for memberGroup: MemberEventGroup, event: GroupedEvent) -> some View {
        let (statusText, _) = getEventStatus(event)
        let barColor = Color(uiColor: event.memberColor)

        return HStack(spacing: 0) {
            // Left color bar with rounded corners
            barColor
                .frame(width: 4)

            // Card content
            VStack(alignment: .leading, spacing: 6) {
                // Member name
                Text(memberGroup.memberName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Event title
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Spacer(minLength: 0)

                // Day name and date
                Text("\(Self.dayOfWeekFormatter.string(from: event.startDate)), \(Self.dateFormatter.string(from: event.startDate))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)

                // Time on its own line to avoid truncation
                if let timeRange = event.timeRange {
                    Text(timeRange)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                }

                // Status on separate line
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .padding(12)
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(uiColor: .systemBackground)))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func getTimeUntilEvent(_ eventDate: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: eventDate)

        if let days = components.day, days > 0 {
            return days == 1 ? "Tomorrow" : "In \(days) days"
        } else if let hours = components.hour, hours > 0 {
            return "In \(hours) hrs"
        } else if let minutes = components.minute, minutes > 0 {
            return "In \(minutes) mins"
        } else {
            return "In Progress"
        }
    }

    private func eventCard(_ groupedEvent: GroupedEvent) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Left side: Date box with color
            VStack(spacing: 2) {
                Text(Self.dayOfWeekFormatter.string(from: groupedEvent.startDate))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))

                Text(Self.dayFormatter.string(from: groupedEvent.startDate))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(Self.monthFormatter.string(from: groupedEvent.startDate))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: 60, height: 70)
            .background {
                if groupedEvent.memberColors.count > 1 {
                    // Gradient fade between multiple colors
                    LinearGradient(
                        gradient: Gradient(colors: groupedEvent.memberColors.map { Color(uiColor: $0) }),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color(uiColor: groupedEvent.memberColor)
                }
            }
            .cornerRadius(8)

            // Right side: Event details
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(groupedEvent.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                // Member names (all people sharing this event)
                Text(groupedEvent.memberNames.joined(separator: ", "))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                    .lineLimit(2)

                // Time
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(groupedEvent.timeRange ?? "All Day")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                // Location (first line only)
                if let location = groupedEvent.location {
                    let firstLine = location.split(separator: "\n").first.map(String.init) ?? location
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(firstLine)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                // Driver (if available)
                if let driverName = groupedEvent.driverName {
                    HStack(spacing: 8) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(driverName)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            Spacer()
        }
        .frame(minHeight: 70)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
    }

    // MARK: - View Lifecycle

    private func setupView() {
        loadNextEvents()
        loadAvailableCalendars()

        // Set up notification observer for calendar changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { _ in
            loadNextEvents()
            loadAvailableCalendars()
        }

        // Set up auto-refresh timer
        startRefreshTimer()
    }

    private func cleanupView() {
        eventsTask?.cancel()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.EKEventStoreChanged, object: eventStore)
        stopRefreshTimer()
    }

    private func startRefreshTimer() {
        stopRefreshTimer()
        // Update current time every minute for status indicators
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentTime = Date()
            // Reload events less frequently (at the auto-refresh interval)
            if Int(Date().timeIntervalSinceReferenceDate) % (autoRefreshInterval * 60) == 0 {
                loadNextEvents()
            }
        }
        // Set initial current time
        currentTime = Date()
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Data Loading

    private func loadNextEvents() {
        eventsTask?.cancel()
        eventsTask = Task { @MainActor in
            isLoadingEvents = true
            defer { isLoadingEvents = false }

            guard !familyMembers.isEmpty else {
                memberEvents = []
                return
            }

            let now = Date()

            // Build map of member → their calendar IDs (from memberCalendarLinks and shared calendars)
            var memberCalendarMap: [NSManagedObjectID: (member: FamilyMember, calendars: Set<String>)] = [:]

            for link in memberCalendarLinks {
                guard let member = link.familyMember,
                      let calendarID = link.calendarID else { continue }
                var entry = memberCalendarMap[member.objectID] ?? (member, [])
                entry.calendars.insert(calendarID)
                memberCalendarMap[member.objectID] = entry
            }

            // Process events per member
            var memberEventGroups: [MemberEventGroup] = []

            for member in familyMembers {
                var calendarIDs = memberCalendarMap[member.objectID]?.calendars ?? []

                // Add shared calendars
                if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
                    for sharedCal in sharedCals {
                        if let calendarID = sharedCal.calendarID {
                            calendarIDs.insert(calendarID)
                        }
                    }
                }

                guard !calendarIDs.isEmpty else { continue }

                // Fetch events for this member
                let upcomingEvents = CalendarManager.shared.fetchNextEvents(
                    for: Array(calendarIDs),
                    limit: 0 // Unlimited so we don't miss future events
                )

                // Convert to EventItem and expand recurring events
                var memberEventItems: [EventItem] = []
                for event in upcomingEvents {
                    let timeRange = formatTimeRange(event.startDate, event.endDate)

                    if event.hasRecurrence, let rule = event.recurrenceRule {
                        // Expand recurring events into individual occurrences
                        let occurrences = expandRecurringEvent(
                            event,
                            rule: rule,
                            limit: eventsPerPerson,
                            now: now
                        )

                        for occurrence in occurrences {
                            let displayID = "\(occurrence.id)|\(occurrence.startDate.timeIntervalSince1970)"
                            let occurrenceTimeRange = formatTimeRange(occurrence.startDate, occurrence.endDate)
                            let driverName = fetchDriverForEvent(occurrence.id)
                            memberEventItems.append(EventItem(
                                id: displayID,
                                eventIdentifier: occurrence.id,
                                title: occurrence.title,
                                location: occurrence.location,
                                startDate: occurrence.startDate,
                                endDate: occurrence.endDate,
                                timeRange: occurrenceTimeRange,
                                memberName: member.name ?? "Unknown",
                                memberColor: event.calendarColor,
                                calendarTitle: event.calendarTitle,
                                calendarID: event.calendarID,
                                hasRecurrence: event.hasRecurrence,
                                recurrenceRule: event.recurrenceRule,
                                isAllDay: occurrence.isAllDay,
                                driverName: driverName
                            ))
                        }
                    } else {
                        let displayID = "\(event.id)|\(event.startDate.timeIntervalSince1970)"
                        // Non-recurring events
                        let driverName = fetchDriverForEvent(event.id)
                        memberEventItems.append(EventItem(
                            id: displayID,
                            eventIdentifier: event.id,
                            title: event.title,
                            location: event.location,
                            startDate: event.startDate,
                            endDate: event.endDate,
                            timeRange: timeRange,
                            memberName: member.name ?? "Unknown",
                            memberColor: event.calendarColor,
                            calendarTitle: event.calendarTitle,
                            calendarID: event.calendarID,
                            hasRecurrence: event.hasRecurrence,
                            recurrenceRule: event.recurrenceRule,
                            isAllDay: event.isAllDay,
                            driverName: driverName
                        ))
                    }
                }

                // Sort member's events by start date
                memberEventItems.sort { $0.startDate < $1.startDate }

                // Filter to only future or in-progress events
                let futureEventItems = memberEventItems.filter { $0.endDate > now }

                // Group this member's events by details (no longer needed to handle recurring specially)
                let groupedMemberEvents = groupEventsByDetails(futureEventItems)

                // Sort grouped events by start date (ensure chronological order)
                let sortedGroupedEvents = groupedMemberEvents.sorted { $0.startDate < $1.startDate }
                let limitedEvents = Array(sortedGroupedEvents.prefix(eventsPerPerson))

                // Create member event group
                let memberColor = Color.fromHex(member.colorHex ?? "#007AFF")
                // Get next non-all-day event for spotlight
                let nextNonAllDayEvent = sortedGroupedEvents.first { !$0.isAllDay && $0.timeRange != nil }
                let memberGroup = MemberEventGroup(
                    id: member.objectID,
                    memberName: member.name ?? "Unknown",
                    memberColor: memberColor,
                    nextEvent: nextNonAllDayEvent,
                    upcomingEvents: limitedEvents
                )

                memberEventGroups.append(memberGroup)
            }

            // Sort member groups alphabetically so Next Events stays organized per person
            memberEventGroups.sort {
                $0.memberName.localizedCaseInsensitiveCompare($1.memberName) == .orderedAscending
            }

            memberEvents = memberEventGroups
        }
    }

    private func fetchDriverForEvent(_ eventIdentifier: String) -> String? {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", eventIdentifier)

        do {
            let results = try viewContext.fetch(fetchRequest)
            if results.isEmpty {
                print("🚗 No FamilyEvent found for eventIdentifier: \(eventIdentifier)")
                // Debug: Let's see what FamilyEvents exist
                let allRequest = FamilyEvent.fetchRequest()
                let allResults = try viewContext.fetch(allRequest)
                print("🚗 Total FamilyEvents in database: \(allResults.count)")
                for event in allResults.prefix(5) {
                    print("   - \(event.eventIdentifier ?? "unknown"): driver = \(event.driver?.name ?? "nil")")
                }
                return nil
            }

            let driverName = results.first?.driver?.name
            if let driverName = driverName {
                print("🚗 Found driver for event \(eventIdentifier): \(driverName)")
            } else {
                print("🚗 FamilyEvent found but no driver for event \(eventIdentifier)")
                print("🚗 FamilyEvent object has driver relationship: \(results.first?.driver != nil)")
            }
            return driverName
        } catch {
            print("🚗 Error fetching driver for event \(eventIdentifier): \(error.localizedDescription)")
            return nil
        }
    }

    private func groupEventsByDetails(_ events: [EventItem]) -> [GroupedEvent] {
        var grouped: [String: GroupedEvent] = [:]

        for event in events {
            // Create a unique key based on event details and start time
            let startKey = String(event.startDate.timeIntervalSinceReferenceDate)
            let key = "\(event.title)|\(startKey)|\(event.timeRange ?? "all-day")|\(event.location ?? "")"

            if let existing = grouped[key] {
                // Build updated member names list
                var updatedNames = existing.memberNames
                if !updatedNames.contains(event.memberName) {
                    updatedNames.append(event.memberName)
                }

                // Build updated colors list
                var updatedColors = existing.memberColors
                if !updatedColors.contains(where: { $0.cgColor == event.memberColor.cgColor }) {
                    updatedColors.append(event.memberColor)
                }

                // Create new merged event
                grouped[key] = GroupedEvent(
                    id: existing.id,
                    eventIdentifier: existing.eventIdentifier,
                    title: existing.title,
                    timeRange: existing.timeRange,
                    location: existing.location,
                    startDate: existing.startDate,
                    endDate: existing.endDate,
                    memberNames: updatedNames,
                    memberColor: existing.memberColor,
                    calendarTitle: existing.calendarTitle,
                    calendarID: existing.calendarID,
                    memberColors: updatedColors,
                    hasRecurrence: existing.hasRecurrence || event.hasRecurrence,
                    isAllDay: existing.isAllDay,
                    driverName: existing.driverName ?? event.driverName
                )
            } else {
                grouped[key] = GroupedEvent(
                    id: event.id,
                    eventIdentifier: event.eventIdentifier,
                    title: event.title,
                    timeRange: event.timeRange,
                    location: event.location,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    memberNames: [event.memberName],
                    memberColor: event.memberColor,
                    calendarTitle: event.calendarTitle,
                    calendarID: event.calendarID,
                    memberColors: [event.memberColor],
                    hasRecurrence: event.hasRecurrence,
                    isAllDay: event.isAllDay,
                    driverName: event.driverName
                )
            }
        }

        return grouped.values.sorted { $0.startDate < $1.startDate }
    }

    private func expandRecurringEvent(_ event: UpcomingCalendarEvent, rule: EKRecurrenceRule, limit: Int, now: Date) -> [UpcomingCalendarEvent] {
        var occurrences: [UpcomingCalendarEvent] = []
        let eventDuration = event.endDate.timeIntervalSince(event.startDate)
        let calendar = Calendar.current

        // Start from the first occurrence or the next future occurrence
        var currentDate = event.startDate
        if currentDate <= now {
            // Find the next future occurrence
            while currentDate.addingTimeInterval(eventDuration) <= now {
                currentDate = advanceByRule(currentDate, rule: rule, calendar: calendar)
            }
        }

        var iterations = 0
        let maxIterations = 100 // Limit iterations to prevent infinite loops

        while iterations < maxIterations && occurrences.count < limit {
            let endDate = currentDate.addingTimeInterval(eventDuration)

            // Only include if the occurrence ends in the future
            if endDate > now {
                let occurrence = UpcomingCalendarEvent(
                    id: event.id,
                    title: event.title,
                    location: event.location,
                    startDate: currentDate,
                    endDate: endDate,
                    calendarID: event.calendarID,
                    calendarColor: event.calendarColor,
                    calendarTitle: event.calendarTitle,
                    hasRecurrence: event.hasRecurrence,
                    recurrenceRule: event.recurrenceRule,
                    isAllDay: event.isAllDay
                )
                occurrences.append(occurrence)
            }

            currentDate = advanceByRule(currentDate, rule: rule, calendar: calendar)
            iterations += 1
        }

        return occurrences
    }

    private func advanceByRule(_ date: Date, rule: EKRecurrenceRule, calendar: Calendar) -> Date {
        let interval = rule.interval
        switch rule.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date) ?? date
        @unknown default:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        }
    }

    private func formatTimeRange(_ startDate: Date, _ endDate: Date) -> String? {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endDate)

        // Check if it's an all-day event (00:00:00 to 00:00:00)
        if startComponents.hour == 0 && startComponents.minute == 0 && startComponents.second == 0 &&
           endComponents.hour == 0 && endComponents.minute == 0 && endComponents.second == 0 {
            return nil
        }

        let startTime = Self.timeFormatter.string(from: startDate)
        let endTime = Self.timeFormatter.string(from: endDate)
        return "\(startTime) – \(endTime)"
    }

    private func reloadEvents() async {
        loadNextEvents()
        // Wait for the task to complete with a brief delay to show refresh indicator
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    private func getEventStatus(_ event: GroupedEvent) -> (status: String, color: Color) {
        let now = currentTime

        // Check if event is in progress
        if event.startDate <= now && now < event.endDate {
            return ("In Progress", .orange)
        }

        // Check if event is upcoming soon (within 1 hour)
        let oneHourFromNow = now.addingTimeInterval(3600)
        if event.startDate > now && event.startDate <= oneHourFromNow {
            return ("Starting Soon", .blue)
        }

        // Default to upcoming
        return ("Upcoming", .gray)
    }

    // MARK: - Context Menu Actions

    private func loadAvailableCalendars() {
        let calendars = eventStore.calendars(for: .event)
        self.availableCalendars = calendars
    }

    private func moveEventToCalendar(_ event: UpcomingCalendarEvent, calendarID: String) {
        // Skip if moving to the same calendar
        if calendarID == event.calendarID {
            return
        }

        if let ekEvent = eventStore.event(withIdentifier: event.id) {
            if let targetCalendar = eventStore.calendar(withIdentifier: calendarID) {
                do {
                    ekEvent.calendar = targetCalendar
                    try eventStore.save(ekEvent, span: .thisEvent, commit: true)

                    // Update CoreData record
                    let fetchRequest = FamilyEvent.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", event.id)
                    if let familyEvent = try viewContext.fetch(fetchRequest).first {
                        familyEvent.calendarId = calendarID
                        try viewContext.save()
                    }

                    print("✅ Event moved to calendar: \(targetCalendar.title)")
                    loadNextEvents()
                } catch {
                    print("❌ Failed to move event: \(error.localizedDescription)")
                }
            }
        }
    }

    private func duplicateEvent(_ event: UpcomingCalendarEvent) {
        let newTitle = "\(event.title) (copy)"
        let duration = event.endDate.timeIntervalSince(event.startDate)

        // Create event 1 hour after the original
        let newStartDate = event.startDate.addingTimeInterval(3600)
        let newEndDate = newStartDate.addingTimeInterval(duration)

        let newEventId = CalendarManager.shared.createEvent(
            title: newTitle,
            startDate: newStartDate,
            endDate: newEndDate,
            location: event.location,
            notes: nil,
            in: event.calendarID
        )

        if let newEventId = newEventId {
            // Create FamilyEvent record if needed
            let familyEvent = FamilyEvent(context: viewContext)
            familyEvent.id = UUID()
            familyEvent.eventGroupId = UUID()
            familyEvent.eventIdentifier = newEventId
            familyEvent.calendarId = event.calendarID
            familyEvent.createdAt = Date()
            familyEvent.isSharedCalendarEvent = false

            do {
                try viewContext.save()
                print("✅ Event duplicated: \(newTitle)")
                loadNextEvents()
            } catch {
                print("❌ Failed to save duplicated event: \(error.localizedDescription)")
            }
        }
    }

    private func deleteEvent(_ event: UpcomingCalendarEvent, span: EKSpan = .thisEvent) {
        let success = CalendarManager.shared.deleteEvent(
            withIdentifier: event.id,
            occurrenceStartDate: event.startDate,
            from: event.calendarID,
            span: span
        )

        if success {
            // Delete from CoreData
            let fetchRequest = FamilyEvent.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", event.id)
            if let familyEvent = try? viewContext.fetch(fetchRequest).first {
                viewContext.delete(familyEvent)
                try? viewContext.save()
            }

            print("✅ Event deleted successfully")
            loadNextEvents()
        }
    }

}

// MARK: - Data Models

private struct EventItem: Identifiable {
    let id: String
    let eventIdentifier: String
    let title: String
    let location: String?
    let startDate: Date
    let endDate: Date
    let timeRange: String?
    let memberName: String
    let memberColor: UIColor
    let calendarTitle: String
    let calendarID: String
    let hasRecurrence: Bool
    let recurrenceRule: EKRecurrenceRule?
    let isAllDay: Bool
    let driverName: String?
}

private struct GroupedEvent: Identifiable {
    let id: String
    let eventIdentifier: String
    let title: String
    let timeRange: String?
    let location: String?
    let startDate: Date
    let endDate: Date
    var memberNames: [String]
    let memberColor: UIColor
    let calendarTitle: String
    let calendarID: String
    var memberColors: [UIColor] = []
    let hasRecurrence: Bool
    let isAllDay: Bool
    let driverName: String?
}

private struct MemberEventGroup: Identifiable {
    let id: NSManagedObjectID
    let memberName: String
    let memberColor: Color
    let nextEvent: GroupedEvent?
    let upcomingEvents: [GroupedEvent]
}

#Preview {
    FamilyView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
