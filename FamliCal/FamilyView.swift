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
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("eventsPerPerson") private var eventsPerPerson: Int = 3
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
    @State private var eventStore = EKEventStore()
    @State private var refreshTimer: Timer? = nil

    private let calendar = Calendar.current
    private let recurrenceChipLimit = 5

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

    private static let recurrenceChipFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()

    var body: some View {
        NavigationView {
            mainScrollView
                .navigationBarHidden(true)
                .sheet(isPresented: $showingEventDetail) {
                    if let event = selectedEvent {
                        EventDetailView(event: event)
                    }
                }
        }
    }

    // MARK: - Child Views

    private var mainScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerView
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
        .onDisappear(perform: cleanupView)
    }

    private var headerView: some View {
        Text("Next Events")
            .font(.system(size: 28, weight: .bold, design: .default))
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
            VStack(alignment: .leading, spacing: 12) {
                Text("Next Events")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 16)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(memberEvents.filter {
                        guard let event = $0.nextEvent else { return false }
                        return event.endDate >= Date()
                    }) { memberGroup in
                        if let nextEvent = memberGroup.nextEvent {
                            Button(action: {
                                selectedEvent = UpcomingCalendarEvent(
                                    id: nextEvent.id,
                                    title: nextEvent.title,
                                    location: nextEvent.location,
                                    startDate: nextEvent.startDate,
                                    endDate: nextEvent.endDate,
                                    calendarColor: nextEvent.memberColor,
                                    calendarTitle: nextEvent.calendarTitle,
                                    hasRecurrence: nextEvent.hasRecurrence,
                                    recurrenceRule: nil
                                )
                                showingEventDetail = true
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
                                                id: groupedEvent.id,
                                                title: groupedEvent.title,
                                                location: groupedEvent.location,
                                                startDate: groupedEvent.startDate,
                                                endDate: groupedEvent.endDate,
                                                calendarColor: groupedEvent.memberColor,
                                                calendarTitle: groupedEvent.calendarTitle,
                                                hasRecurrence: groupedEvent.hasRecurrence,
                                                recurrenceRule: nil
                                            )
                                            showingEventDetail = true
                                        }) {
                                            eventCard(groupedEvent)
                                        }
                                        .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(memberGroup.memberName.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(memberGroup.memberColor)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(memberGroup.memberName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(event.calendarTitle)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Text(Self.dateFormatter.string(from: event.startDate))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray)

                Text(event.timeRange ?? "All Day")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack {
                Text(getTimeUntilEvent(event.startDate))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(14)

                Spacer()

                Circle()
                    .fill(Color(uiColor: event.memberColor))
                    .frame(width: 10, height: 10)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
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
                Text(Self.dayFormatter.string(from: groupedEvent.startDate))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text(Self.dayOfWeekFormatter.string(from: groupedEvent.startDate))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: 70, height: 90)
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
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(groupedEvent.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                // Member names
                Text(groupedEvent.memberNames.joined(separator: ", "))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                // Time
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(groupedEvent.timeRange ?? "All Day")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                // Location
                if let location = groupedEvent.location {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }

                if !groupedEvent.recurrenceChips.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                        ForEach(groupedEvent.recurrenceChips) { chip in
                            Text(chip.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }

            Spacer()
        }
        .frame(minHeight: 100)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
    }

    // MARK: - View Lifecycle

    private func setupView() {
        loadNextEvents()

        // Set up notification observer for calendar changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { _ in
            loadNextEvents()
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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(autoRefreshInterval * 60), repeats: true) { _ in
            loadNextEvents()
        }
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
                    limit: 100 // Fetch enough to group and filter
                )

                // Convert to EventItem
                var memberEventItems: [EventItem] = []
                for event in upcomingEvents {
                    let timeRange = formatTimeRange(event.startDate, event.endDate)
                    memberEventItems.append(EventItem(
                        id: UUID(),
                        title: event.title,
                        location: event.location,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        timeRange: timeRange,
                        memberName: member.name ?? "Unknown",
                        memberColor: event.calendarColor,
                        calendarTitle: event.calendarTitle,
                        hasRecurrence: event.hasRecurrence,
                        recurrenceRule: event.recurrenceRule
                    ))
                }

                // Sort member's events by start date
                memberEventItems.sort { $0.startDate < $1.startDate }

                // Group this member's events by details
                let groupedMemberEvents = groupEventsByDetails(memberEventItems)

                // Keep only future or in-progress events
                let upcomingMemberEvents = groupedMemberEvents.filter { $0.endDate >= now }

                // Attach recurrence chips to recurring events
                let decoratedEvents = attachRecurringChips(
                    upcomingMemberEvents,
                    upcomingEvents: upcomingEvents
                )

                let limitedEvents = Array(decoratedEvents.prefix(eventsPerPerson))

                // Create member event group
                let memberColor = Color.fromHex(member.colorHex ?? "#007AFF")
                let memberGroup = MemberEventGroup(
                    id: member.objectID,
                    memberName: member.name ?? "Unknown",
                    memberColor: memberColor,
                    nextEvent: decoratedEvents.first,
                    upcomingEvents: limitedEvents
                )

                memberEventGroups.append(memberGroup)
            }

            // Sort member groups by their first event date
            memberEventGroups.sort { (group1, group2) in
                let date1 = group1.upcomingEvents.first?.startDate ?? Date.distantFuture
                let date2 = group2.upcomingEvents.first?.startDate ?? Date.distantFuture
                return date1 < date2
            }

            memberEvents = memberEventGroups
        }
    }

    private func groupEventsByDetails(_ events: [EventItem]) -> [GroupedEvent] {
        var grouped: [String: GroupedEvent] = [:]

        for event in events {
            let startKey = String(event.startDate.timeIntervalSinceReferenceDate)
            let key = "\(event.title)|\(startKey)|\(event.timeRange ?? "all-day")|\(event.location ?? "")"

            if var existing = grouped[key] {
                // Add member name if not already present
                if !existing.memberNames.contains(event.memberName) {
                    existing.memberNames.append(event.memberName)
                }
                // Add color if it's not already in the list
                if !existing.memberColors.contains(where: { $0.cgColor == event.memberColor.cgColor }) {
                    existing.memberColors.append(event.memberColor)
                }
                grouped[key] = existing
            } else {
                grouped[key] = GroupedEvent(
                    id: event.id.uuidString,
                    title: event.title,
                    timeRange: event.timeRange,
                    location: event.location,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    memberNames: [event.memberName],
                    memberColor: event.memberColor,
                    calendarTitle: event.calendarTitle,
                    hasRecurrence: event.hasRecurrence,
                    recurrenceRule: event.recurrenceRule,
                    memberColors: [event.memberColor]
                )
            }
        }

        return grouped.values.sorted { $0.startDate < $1.startDate }
    }

    private func attachRecurringChips(_ groupedEvents: [GroupedEvent], upcomingEvents: [UpcomingCalendarEvent]) -> [GroupedEvent] {
        var decoratedEvents = groupedEvents

        for index in decoratedEvents.indices {
            guard decoratedEvents[index].hasRecurrence,
                  let recurrenceRule = decoratedEvents[index].recurrenceRule else { continue }

            let occurrenceDates = CalendarManager.shared.calculateRecurringOccurrences(
                startDate: decoratedEvents[index].startDate,
                endDate: decoratedEvents[index].endDate,
                recurrenceRule: recurrenceRule,
                upcomingEvents: upcomingEvents,
                currentEventId: decoratedEvents[index].id,
                eventTitle: decoratedEvents[index].title,
                limit: recurrenceChipLimit
            )

            let chips = occurrenceDates.map { occurrenceDate in
                RecurrenceChip(
                    date: occurrenceDate,
                    label: Self.recurrenceChipFormatter.string(from: occurrenceDate)
                )
            }

            decoratedEvents[index].recurrenceChips = chips
        }

        return decoratedEvents
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

}

// MARK: - Data Models

private struct EventItem: Identifiable {
    let id: UUID
    let title: String
    let location: String?
    let startDate: Date
    let endDate: Date
    let timeRange: String?
    let memberName: String
    let memberColor: UIColor
    let calendarTitle: String
    let hasRecurrence: Bool
    let recurrenceRule: EKRecurrenceRule?
}

private struct GroupedEvent: Identifiable {
    let id: String
    let title: String
    let timeRange: String?
    let location: String?
    let startDate: Date
    let endDate: Date
    var memberNames: [String]
    let memberColor: UIColor
    let calendarTitle: String
    let hasRecurrence: Bool
    let recurrenceRule: EKRecurrenceRule?
    var memberColors: [UIColor] = []
    var recurrenceChips: [RecurrenceChip] = []
}

private struct MemberEventGroup: Identifiable {
    let id: NSManagedObjectID
    let memberName: String
    let memberColor: Color
    let nextEvent: GroupedEvent?
    let upcomingEvents: [GroupedEvent]
}

private struct RecurrenceChip: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
}

#Preview {
    FamilyView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
