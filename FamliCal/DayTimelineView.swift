//
//  DayTimelineView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import EventKit

struct DayTimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext

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

    @State private var selectedDate = Date()
    @State private var dayEvents: [TimelineEvent] = []
    @State private var selectedMembers: Set<String> = []
    @State private var showMemberFilter = false
    @State private var eventStore = EKEventStore()
    @State private var isLoadingEvents = false
    @State private var currentTime = Date()
    @State private var timelineTimer: Timer?

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60 // Height per hour in timeline
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private let dateHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with date and navigation
                VStack(spacing: 12) {
                    HStack {
                        Button(action: previousDay) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }

                        VStack(spacing: 4) {
                            Text(dateHeaderFormatter.string(from: selectedDate))
                                .font(.system(size: 18, weight: .semibold))

                            if isToday(selectedDate) {
                                Text("Today")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Button(action: nextDay) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Member filter pills
                    if !familyMembers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(familyMembers, id: \.objectID) { member in
                                    let memberColor = Color.fromHex(member.colorHex ?? "#007AFF")
                                    let isSelected = selectedMembers.contains(member.objectID.uriRepresentation().absoluteString)

                                    Button(action: { toggleMember(member) }) {
                                        Text(member.name ?? "Unknown")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(isSelected ? memberColor : Color(.systemGray5))
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)

                // Timeline
                if isLoadingEvents {
                    VStack {
                        ProgressView()
                            .tint(.blue)
                        Text("Loading events...")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if dayEvents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)

                        Text("No events scheduled")
                            .font(.system(size: 16, weight: .semibold))

                        Text("Enjoy your free time!")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    timelineView
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear(perform: loadEventsForSelectedDate)
        .onChange(of: selectedDate) { _, _ in loadEventsForSelectedDate() }
        .onChange(of: selectedMembers) { _, _ in loadEventsForSelectedDate() }
        .onDisappear(perform: stopTimelineTimer)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 50 {
                        previousDay()
                    } else if value.translation.width < -50 {
                        nextDay()
                    }
                }
        )
    }

    private var timelineView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        // Time slots from 6 AM to 10 PM
                        ForEach(6..<23, id: \.self) { hour in
                            timelineHour(hour: hour)
                                .id("hour-\(hour)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Current time indicator (only show if it's today and within 6-23 range)
                    if calendar.isDateInToday(selectedDate) && currentTimeInRange {
                        VStack {
                            Spacer(minLength: currentTimeOffset)

                            HStack(spacing: 8) {
                                Text(timeFormatter.string(from: currentTime))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.red)

                                Divider()
                                    .frame(height: 1)
                                    .background(Color.red)
                            }
                            .padding(.leading, 16)

                            Spacer()
                        }
                    }
                }
                .onAppear {
                    startTimelineTimer()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let currentHour = Calendar.current.component(.hour, from: Date())
                        if currentHour >= 6 && currentHour < 23 {
                            proxy.scrollTo("hour-\(currentHour)", anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private var currentTimeInRange: Bool {
        let hour = calendar.component(.hour, from: currentTime)
        return hour >= 6 && hour < 23
    }

    private var currentTimeOffset: CGFloat {
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let hoursSince6 = CGFloat(max(0, hour - 6))
        let minuteFraction = CGFloat(minute) / 60.0
        return (hoursSince6 + minuteFraction) * hourHeight + 8
    }

    private func timelineHour(hour: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(width: 40, alignment: .leading)
                    .padding(.top, 4)

                VStack(spacing: 8) {
                    // Get events for this hour
                    let hoursEvents = dayEvents.filter { event in
                        let startHour = calendar.component(.hour, from: event.startDate)
                        let endHour = calendar.component(.hour, from: event.endDate)
                        return (startHour == hour) || (startHour < hour && hour < endHour)
                    }

                    if !hoursEvents.isEmpty {
                        ForEach(hoursEvents, id: \.id) { event in
                            eventCard(event)
                        }
                    }

                    Spacer()
                        .frame(height: 52) // 1 hour height
                }
            }

            Divider()
                .padding(.leading, 52)
        }
    }

    private func eventCard(_ event: TimelineEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)

            HStack(spacing: 4) {
                Text(timeFormatter.string(from: event.startDate))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.9))

                if !event.memberNames.isEmpty {
                    Text("• \(event.memberNames.joined(separator: ", "))")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: event.color))
        )
    }

    private func previousDay() {
        selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    private func nextDay() {
        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func toggleMember(_ member: FamilyMember) {
        let id = member.objectID.uriRepresentation().absoluteString
        if selectedMembers.contains(id) {
            selectedMembers.remove(id)
        } else {
            selectedMembers.insert(id)
        }
    }

    private func loadEventsForSelectedDate() {
        isLoadingEvents = true

        // Initialize selected members to include all if none selected
        if selectedMembers.isEmpty {
            for member in familyMembers {
                selectedMembers.insert(member.objectID.uriRepresentation().absoluteString)
            }
        }

        // Get calendar IDs for selected members
        var calendarIDs: Set<String> = []
        for member in familyMembers {
            let memberId = member.objectID.uriRepresentation().absoluteString
            guard selectedMembers.contains(memberId) else { continue }

            // Add member's calendars
            if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
                for cal in memberCals {
                    if let calID = cal.calendarID {
                        calendarIDs.insert(calID)
                    }
                }
            }

            // Add shared calendars
            if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
                for cal in sharedCals {
                    if let calID = cal.calendarID {
                        calendarIDs.insert(calID)
                    }
                }
            }
        }

        // Fetch events for the selected date
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let eventPredicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: eventStore.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) })
        let ekEvents = eventStore.events(matching: eventPredicate).sorted { $0.startDate < $1.startDate }

        // Convert to TimelineEvent
        dayEvents = ekEvents.map { ekEvent in
            let memberName = familyMembers.first(where: { member in
                if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar> {
                    return memberCals.contains { $0.calendarID == ekEvent.calendar.calendarIdentifier }
                }
                return false
            })?.name ?? "Unknown"

            let color = UIColor(cgColor: ekEvent.calendar.cgColor)

            return TimelineEvent(
                id: ekEvent.eventIdentifier,
                title: ekEvent.title,
                startDate: ekEvent.startDate,
                endDate: ekEvent.endDate,
                memberNames: [memberName],
                color: color,
                location: ekEvent.location
            )
        }

        isLoadingEvents = false
    }

    private func startTimelineTimer() {
        stopTimelineTimer()
        timelineTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func stopTimelineTimer() {
        timelineTimer?.invalidate()
        timelineTimer = nil
    }
}

struct TimelineEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let memberNames: [String]
    let color: UIColor
    let location: String?
}

#Preview {
    DayTimelineView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
