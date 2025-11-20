//
//  EventDetailView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import EventKit
import MapKit
import CoreLocation
import CoreData

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("defaultMapsApp") private var defaultMapsApp: String = "Apple Maps"
    let event: UpcomingCalendarEvent

    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var ekEvent: EKEvent?
    @State private var alerts: [EKAlarm] = []
    @State private var mapRegion = MKCoordinateRegion()
    @State private var locationCoordinates: CLLocationCoordinate2D?
    @State private var isLoadingLocation = false
    @State private var showingCalendarPicker = false
    @State private var showingRecurringDeleteOptions = false
    @State private var driver: Driver?
    @State private var eventStore = EKEventStore()
    @State private var availableCalendars: [EKCalendar] = []

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text(event.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .contextMenu {
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
                            if event.hasRecurrence {
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
                                Button(role: .destructive, action: { deleteEvent(event) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                    // Location (smaller text, red) - tappable to open maps
                    if let location = event.location, !location.isEmpty {
                        Button(action: { MapsUtility.openLocation(location, in: defaultMapsApp) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.red)

                                    Text(location)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.red)
                                        .lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Date and Time on same line
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Self.fullDateFormatter.string(from: event.startDate))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("\(Self.timeFormatter.string(from: event.startDate)) – \(Self.timeFormatter.string(from: event.endDate))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)

                    // Calendar selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calendar")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)

                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(uiColor: event.calendarColor))
                                .frame(width: 14, height: 14)

                            Text(event.calendarTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                    }

                    // Driver section
                    if let driver = driver {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Driver")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(driver.name ?? "Unknown Driver")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)

                                        if let phone = driver.phone, !phone.isEmpty {
                                            Button(action: { callDriver(phone: phone) }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "phone.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.blue)

                                                    Text(phone)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                        }

                                        if let email = driver.email, !email.isEmpty {
                                            Button(action: { emailDriver(email: email) }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "envelope.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.blue)

                                                    Text(email)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                if let notes = driver.notes, !notes.isEmpty {
                                    Divider()
                                        .padding(.horizontal, 16)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Notes")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.gray)

                                        Text(notes)
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                            .lineLimit(5)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                        }
                    }

                    // Alerts section
                    if !alerts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Alerts")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                ForEach(Array(alerts.enumerated()), id: \.offset) { index, alarm in
                                    HStack(spacing: 12) {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.blue)

                                        Text(alertDisplayText(alarm))
                                            .font(.system(size: 15, weight: .regular))
                                            .foregroundColor(.gray)

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    if index < alerts.count - 1 {
                                        Divider()
                                            .padding(.horizontal, 16)
                                    }
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal, 20)
                        }
                    }

                    // Map section
                    if locationCoordinates != nil {
                        VStack(spacing: 0) {
                            Map(position: .constant(.region(mapRegion)))
                                .frame(height: 250)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    } else if isLoadingLocation {
                        HStack {
                            ProgressView()
                                .tint(.blue)
                            Text("Loading map...")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }

                    // Recurring indicator
                    if event.hasRecurrence {
                        HStack(spacing: 8) {
                            Image(systemName: "repeat.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)

                            Text("This is a recurring event")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                    }

                    // Delete button
                    Button(action: handleDeleteTap) {
                        Text("Delete Event")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    Spacer(minLength: 20)
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isEditing = true }) {
                        Text("Edit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                EditEventView(upcomingEvent: event)
            }
            .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteEvent()
                }
            } message: {
                Text("Are you sure you want to delete this event?")
            }
            .confirmationDialog("Delete Recurring Event?", isPresented: $showingRecurringDeleteOptions, titleVisibility: .visible) {
                Button("Delete Only This Event", role: .destructive) {
                    deleteEvent(span: .thisEvent)
                }
                Button("Delete This and Future Events", role: .destructive) {
                    deleteEvent(span: .futureEvents)
                }
                Button("Cancel", role: .cancel) { }
            }
            .onAppear {
                // Load available calendars for context menu
                loadAvailableCalendars()

                // Try to fetch event details, but don't fail if we can't
                fetchEventDetails()

                // Load location map regardless of event details
                if let location = event.location, !location.isEmpty {
                    geocodeLocation(location)
                }

                // Fetch driver information
                fetchDriver()
            }
        }
    }

    // MARK: - Helper Methods

    private func fetchDriver() {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", event.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            print("🚗 Fetching driver for event: \(event.id)")
            print("   FamilyEvents found: \(results.count)")

            if let familyEvent = results.first {
                self.driver = familyEvent.driver
                print("✅ Driver loaded: \(familyEvent.driver?.name ?? "nil")")
            } else {
                print("ℹ️ No FamilyEvent found for this event")
            }
        } catch {
            print("❌ Failed to fetch driver for event: \(error.localizedDescription)")
        }
    }

    private func callDriver(phone: String) {
        let cleanedPhone = phone.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel:\(cleanedPhone)") {
            UIApplication.shared.open(url)
        }
    }

    private func emailDriver(email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }

    private func fetchEventDetails() {
        // Try to fetch full event details for alarms, but continue without them if not available
        // This prevents crashes if the event has been deleted or is inaccessible
        guard let ekEvent = CalendarManager.shared.fetchEventDetails(
            withIdentifier: event.id,
            occurrenceStartDate: event.startDate
        ) else {
            print("⚠️ Could not find full event details for: \(event.id)")
            print("   Event may have been deleted or is inaccessible")
            return
        }

        self.ekEvent = ekEvent
        self.alerts = ekEvent.alarms ?? []
    }

    private func geocodeLocation(_ locationString: String) {
        isLoadingLocation = true

        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = locationString

            let geocoder = MKLocalSearch(request: request)
            do {
                let response = try await geocoder.start()
                await MainActor.run {
                    isLoadingLocation = false
                    if let firstResult = response.mapItems.first {
                        let coordinate = firstResult.location.coordinate
                        locationCoordinates = coordinate
                        mapRegion = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingLocation = false
                }
            }
        }
    }

    private func handleDeleteTap() {
        if event.hasRecurrence {
            showingRecurringDeleteOptions = true
        } else {
            showingDeleteConfirmation = true
        }
    }

    private func deleteEvent(span: EKSpan = .thisEvent) {
        isDeleting = true

        // Use CalendarManager to ensure we're using the same EventStore instance
        let success = CalendarManager.shared.deleteEvent(
            withIdentifier: event.id,
            occurrenceStartDate: event.startDate,
            from: event.calendarID,
            span: span
        )

        if success {
            DispatchQueue.main.async {
                dismiss()
            }
        } else {
            DispatchQueue.main.async {
                isDeleting = false
            }
        }
    }

    private func alertDisplayText(_ alarm: EKAlarm) -> String {
        let minutes = abs(Int(alarm.relativeOffset / 60))

        if minutes == 0 {
            return "At time of event"
        } else if minutes < 60 {
            return minutes == 1 ? "1 minute before" : "\(minutes) minutes before"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour before" : "\(hours) hours before"
        } else {
            let days = minutes / 1440
            return days == 1 ? "1 day before" : "\(days) days before"
        }
    }

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
                    dismiss()
                } catch {
                    print("❌ Failed to move event: \(error.localizedDescription)")
                }
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
            dismiss()
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
                // Show a success message and dismiss
                dismiss()
            } catch {
                print("❌ Failed to save duplicated event: \(error.localizedDescription)")
            }
        }
    }

}

#Preview {
    let testEvent = UpcomingCalendarEvent(
        id: "123",
        title: "Knee Op",
        location: "London Bridge Hospital",
        startDate: Date().addingTimeInterval(3600),
        endDate: Date().addingTimeInterval(7200),
        calendarID: "work-calendar",
        calendarColor: UIColor.blue,
        calendarTitle: "Mark",
        hasRecurrence: false,
        recurrenceRule: nil,
        isAllDay: false
    )

    EventDetailView(event: testEvent)
}
