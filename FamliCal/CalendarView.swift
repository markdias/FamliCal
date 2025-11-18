//
//  CalendarView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import EventKit
import Combine
import MapKit

struct CalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval: Int = 5
    @AppStorage("defaultMapsApp") private var defaultMapsApp: String = "Apple Maps"

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

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var dayEvents: [String: [DayEventItem]] = [:]
    @State private var isLoadingEvents = false
    @State private var showingEventDetail = false
    @State private var eventStore = EKEventStore()
    @State private var refreshTimer: Timer? = nil

    private let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday as first day
        return calendar
    }()
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
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

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomLeading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header with centered month/year
                        VStack(spacing: 12) {
                            Text(Self.monthFormatter.string(from: currentMonth))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)

                        // Calendar grid
                        VStack(spacing: 8) {
                            // Day headers (Mon ... Sun)
                            HStack(spacing: 0) {
                                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                                    Text(day)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                            }
                            .padding(.bottom, 4)

                            // Calendar days
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(getDaysInMonth(), id: \.self) { date in
                                    calendarDayCell(for: date)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if value.translation.width > 50 {
                                        previousMonth()
                                    } else if value.translation.width < -50 {
                                        nextMonth()
                                    }
                                }
                        )

                        // Today button
                        HStack {
                            Spacer()
                            Button(action: {
                                currentMonth = Date()
                                selectedDate = Date()
                            }) {
                                Text("Today")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(6)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        // Selected day details
                        if let events = dayEvents[formatDateKey(selectedDate)], !events.isEmpty {
                            dayDetailsView(for: events)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(Self.fullDateFormatter.string(from: selectedDate))
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(.horizontal, 2)

                                HStack {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)

                                    Text("No events scheduled")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)

                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationBarHidden(true)
        }
        .onAppear(perform: setupView)
        .onChange(of: currentMonth) { _, _ in loadEvents() }
        .onChange(of: familyMembers.count) { _, _ in loadEvents() }
        .onChange(of: memberCalendarLinks.count) { _, _ in loadEvents() }
        .onChange(of: autoRefreshInterval) { _, _ in startRefreshTimer() }
        .onDisappear(perform: cleanupView)
    }

    @ViewBuilder
    private func dayDetailsView(for events: [DayEventItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Self.fullDateFormatter.string(from: selectedDate))
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 2)

            // Group events by title, time, and location
            let groupedEvents = groupEventsByDetails(events)

            VStack(spacing: 4) {
                ForEach(Array(groupedEvents.enumerated()), id: \.element.id) { _, groupedEvent in
                    HStack(spacing: 16) {
                        // Left side: Colored square with start time
                        VStack(spacing: 2) {
                            if let startTime = groupedEvent.startTime {
                                Text(startTime)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text("All")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Day")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 90, height: 70)
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

                            // Member names
                            Text(groupedEvent.memberNames.joined(separator: ", "))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                                .lineLimit(1)

                            // Time
                            if let timeRange = groupedEvent.timeRange {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                    Text(timeRange)
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                    Text("All Day")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                            }

                            // Location (first line only) - tappable to open maps
                            if let location = groupedEvent.location {
                                let firstLine = location.split(separator: "\n").first.map(String.init) ?? location
                                Button(action: { openLocationInMaps(firstLine) }) {
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
                            }

                            Spacer()
                        }

                        Spacer()
                    }
                    .frame(minHeight: 70)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.85))
                    .cornerRadius(12)
                }
            }
        }
    }

    private func groupEventsByDetails(_ events: [DayEventItem]) -> [GroupedDayEvent] {
        var grouped: [String: GroupedDayEvent] = [:]

        for event in events {
            let key = "\(event.title)|\(event.timeRange ?? "all-day")|\(event.location ?? "")"

            if var existing = grouped[key] {
                existing.memberNames.append(event.memberName)
                // Add color if it's not already in the list
                if !existing.memberColors.contains(where: { $0.cgColor == event.memberColor.cgColor }) {
                    existing.memberColors.append(event.memberColor)
                }
                grouped[key] = existing
            } else {
                grouped[key] = GroupedDayEvent(
                    id: UUID(),
                    title: event.title,
                    timeRange: event.timeRange,
                    location: event.location,
                    memberNames: [event.memberName],
                    memberInitials: event.memberInitials,
                    memberColor: event.memberColor,
                    color: event.color,
                    memberColors: [event.memberColor]
                )
            }
        }

        return grouped.values.sorted { e1, e2 in
            e1.timeRange ?? "" < e2.timeRange ?? ""
        }
    }

    // MARK: - Helper Functions

    private func calendarDayCell(for date: Date) -> some View {
        let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let isToday = calendar.isDate(date, inSameDayAs: Date())
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let hasEvents = dayEvents[formatDateKey(date)] != nil && !dayEvents[formatDateKey(date)]!.isEmpty
        let eventCount = dayEvents[formatDateKey(date)]?.count ?? 0

        return VStack(alignment: .leading, spacing: 2) {
            Text(Self.dayFormatter.string(from: date))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(
                    isSelected ? .white
                    : !isCurrentMonth ? .gray.opacity(0.5)
                    : isToday ? .blue
                    : .primary
                )

            Spacer()

            // Event indicators (dots)
            if hasEvents {
                HStack(spacing: 1) {
                    ForEach(0..<min(3, eventCount), id: \.self) { index in
                        Circle()
                            .fill(Color(uiColor: dayEvents[formatDateKey(date)]![index].color))
                            .frame(width: 3, height: 3)
                    }
                    if eventCount > 3 {
                        Text("+")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .frame(minHeight: 52)
        .background(
            isSelected ? Color.blue
            : !isCurrentMonth ? Color(.systemGray5).opacity(0.3)
            : isToday ? Color.blue.opacity(0.15)
            : hasEvents ? Color.blue.opacity(0.06)
            : Color(.systemGray6)
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isToday && !isSelected ? Color.blue.opacity(0.3) : Color.clear,
                    lineWidth: 2
                )
        )
        .onTapGesture {
            if isCurrentMonth {
                selectedDate = date
            }
        }
        .opacity(isCurrentMonth ? 1 : 0.6)
    }

    private func getDaysInMonth() -> [Date] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let numDays = range.count

        // Get the first day of the month
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: currentMonth)
        components.day = 1
        let firstOfMonth = calendar.date(from: components)!

        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let firstWeekday = (weekday + 5) % 7 // shift so Monday = 0

        var days: [Date] = []

        // Add empty dates from previous month
        if firstWeekday > 0 {
            for i in 0..<firstWeekday {
                let date = calendar.date(byAdding: .day, value: -(firstWeekday - i), to: firstOfMonth)!
                days.append(date)
            }
        }

        // Add days of current month
        for day in 1...numDays {
            let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
            days.append(date)
        }

        // Add empty dates from next month
        let remainingDays = 42 - days.count // 6 rows x 7 days
        let lastDayOfMonth = calendar.date(byAdding: .day, value: numDays - 1, to: firstOfMonth)!
        for day in 1...remainingDays {
            let date = calendar.date(byAdding: .day, value: day, to: lastDayOfMonth)!
            days.append(date)
        }

        return days
    }

    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
            updateSelectedDateForMonth(newMonth)
        }
    }

    private func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
            updateSelectedDateForMonth(newMonth)
        }
    }

    private func updateSelectedDateForMonth(_ month: Date) {
        let today = Date()
        if calendar.isDate(month, equalTo: today, toGranularity: .month) {
            // Current month: select today
            selectedDate = today
        } else {
            // Other months: select the 1st
            var components = calendar.dateComponents([.year, .month], from: month)
            components.day = 1
            if let firstOfMonth = calendar.date(from: components) {
                selectedDate = firstOfMonth
            }
        }
    }

    private func loadEvents() {
        isLoadingEvents = true

        var eventsDict: [String: [DayEventItem]] = [:]

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let endOfMonth = calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .month, value: 1, to: startOfMonth)!)!

        // Build map of member → their calendar IDs
        var memberCalendarMap: [NSManagedObjectID: (Set<String>, FamilyMember)] = [:]

        for link in memberCalendarLinks {
            guard let member = link.familyMember,
                  let calendarID = link.calendarID else { continue }
            var entry = memberCalendarMap[member.objectID] ?? ([], member)
            entry.0.insert(calendarID)
            memberCalendarMap[member.objectID] = entry
        }

        // Add shared calendars
        for member in familyMembers {
            var entry = memberCalendarMap[member.objectID] ?? ([], member)
            if let sharedCals = member.sharedCalendars as? Set<SharedCalendar> {
                for sharedCal in sharedCals {
                    if let calendarID = sharedCal.calendarID {
                        entry.0.insert(calendarID)
                    }
                }
            }
            if !entry.0.isEmpty {
                memberCalendarMap[member.objectID] = entry
            }
        }

        // Fetch events for each member
        for (_, (calendarIDs, member)) in memberCalendarMap {
            let events = CalendarManager.shared.fetchNextEvents(for: Array(calendarIDs), limit: 100)

            let initials = member.avatarInitials ?? Self.initials(for: member.name)

            for event in events {
                let eventDate = calendar.startOfDay(for: event.startDate)
                let monthDate = calendar.startOfDay(for: endOfMonth)

                if eventDate >= startOfMonth && eventDate <= monthDate {
                    let dateKey = formatDateKey(eventDate)

                    let timeRange = event.startDate == event.endDate ? nil : {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
                    }()

                    let dayEvent = DayEventItem(
                        id: UUID(),
                        title: event.title,
                        timeRange: timeRange,
                        location: event.location,
                        memberName: member.name ?? "Unknown",
                        memberInitials: initials,
                        memberColor: event.calendarColor,
                        color: event.calendarColor
                    )

                    if eventsDict[dateKey] == nil {
                        eventsDict[dateKey] = []
                    }
                    eventsDict[dateKey]?.append(dayEvent)
                }
            }
        }

        dayEvents = eventsDict
        isLoadingEvents = false
    }

    private static func initials(for name: String?) -> String {
        guard let name = name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        let combined = (first + second)
        if combined.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return combined.uppercased()
    }

    // MARK: - View Lifecycle

    private func setupView() {
        loadEvents()
        startRefreshTimer()
    }

    private func cleanupView() {
        stopRefreshTimer()
    }

    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(autoRefreshInterval * 60), repeats: true) { _ in
            loadEvents()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func openLocationInMaps(_ location: String) {
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location

        switch defaultMapsApp {
        case "Google Maps":
            if let googleMapsURL = URL(string: "comgooglemaps://?q=\(encodedLocation)"),
               UIApplication.shared.canOpenURL(googleMapsURL) {
                UIApplication.shared.open(googleMapsURL)
            } else if let webURL = URL(string: "https://maps.google.com/?q=\(encodedLocation)") {
                UIApplication.shared.open(webURL)
            }
        case "Waze":
            if let wazeURL = URL(string: "waze://?q=\(encodedLocation)"),
               UIApplication.shared.canOpenURL(wazeURL) {
                UIApplication.shared.open(wazeURL)
            } else if let webURL = URL(string: "https://www.waze.com/ul?q=\(encodedLocation)") {
                UIApplication.shared.open(webURL)
            }
        default: // Apple Maps
            if let appleURL = URL(string: "maps://?q=\(encodedLocation)") {
                UIApplication.shared.open(appleURL)
            }
        }
    }
}

// MARK: - Data Models

struct DayEventItem: Identifiable {
    let id: UUID
    let title: String
    let timeRange: String?
    let location: String?
    let memberName: String
    let memberInitials: String
    let memberColor: UIColor
    let color: UIColor

    var startTime: String? {
        guard let timeRange = timeRange else { return nil }
        return timeRange.split(separator: "–").first?.trimmingCharacters(in: .whitespaces)
    }
}

struct GroupedDayEvent: Identifiable {
    let id: UUID
    let title: String
    let timeRange: String?
    let location: String?
    var memberNames: [String]
    let memberInitials: String
    let memberColor: UIColor
    let color: UIColor
    var memberColors: [UIColor] = []  // Store all colors for gradient

    var startTime: String? {
        guard let timeRange = timeRange else { return nil }
        return timeRange.split(separator: "–").first?.trimmingCharacters(in: .whitespaces)
    }
}

#Preview {
    CalendarView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
