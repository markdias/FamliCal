//
//  EditEventView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import MapKit
import Combine
import EventKit

struct EditEventView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let upcomingEvent: UpcomingCalendarEvent

    @FetchRequest(
        entity: Driver.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Driver.name, ascending: true)]
    )
    private var drivers: FetchedResults<Driver>

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    // Family members who are marked as drivers
    private var driverFamilyMembers: [FamilyMember] {
        familyMembers.filter { $0.isDriver }
    }

    // Combined list of all available drivers (regular + family members)
    private var allAvailableDrivers: [DriverWrapper] {
        var combined: [DriverWrapper] = []

        // Add regular drivers
        for driver in drivers {
            combined.append(.regular(driver))
        }

        // Add family members who are marked as drivers
        for member in driverFamilyMembers {
            combined.append(.familyMember(member))
        }

        // Sort by name
        return combined.sorted { $0.name < $1.name }
    }

    // Event details
    @State private var eventTitle: String = ""
    @State private var eventDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var notes: String = ""
    @State private var locationName: String = ""
    @State private var locationAddress: String = ""
    @State private var isAllDay: Bool = false
    @State private var showAsOption: ShowAsOption = .busy
    @State private var repeatOption: RepeatOption = .none
    @State private var recurrenceConfig = RecurrenceConfiguration.none(anchor: Date())
    @State private var showingCustomRepeatSheet = false
    @State private var alertOption: AlertOption = .none

    // Location search
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var isApplyingLocationSelection = false

    // Calendar info for updating
    @State private var calendarId: String? = nil
    @State private var selectedMemberCalendars: [NSManagedObjectID: String] = [:] // Track calendar per member

    // Driver selection
    @State private var selectedDriver: DriverWrapper?
    @State private var driverTravelTimeMinutes: Int = 15

    // UI state
    @State private var showingStartDatePicker = false
    @State private var showingEndDatePicker = false
    @State private var showingStartTimePicker = false
    @State private var showingEndTimePicker = false
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingRecurringDeleteOptions = false
    @State private var showingSuccessMessage = false
    @State private var showingDeleteSuccess = false
    private let notificationManager = NotificationManager.shared

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { Color.black.opacity(0.9) }
    private var secondaryTextColor: Color { Color.black.opacity(0.55) }
    private var formBackground: Color { Color(red: 0.95, green: 0.95, blue: 0.97) }
    private var cardBackground: Color { Color.white }
    private var sectionBorder: Color { Color.black.opacity(0.04) }
    private var fieldBackground: Color { Color.white }
    private var chipBackground: Color { Color(red: 0.9, green: 0.9, blue: 0.93) }
    private var accentColor: Color { theme.accentColor }

    @ViewBuilder
    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(primaryTextColor)
    }

    var isFormValid: Bool {
        !eventTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                formBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        titleSection
                        locationSection
                        timeSection
                        repeatSection
                        alertSection
                        calendarSection
                        driverSection
                        notesSection
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(16)
                }
                .background(Color.clear)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: handleDeleteTap) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                        }

                        Button(action: {
                            Task { await saveEvent() }
                        }) {
                            if isSaving {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .disabled(!isFormValid || isSaving)
                    }
                }
            }
            .confirmationDialog("Delete Event", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { await deleteEvent() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this event? This cannot be undone.")
            }
            .confirmationDialog("Delete Recurring Event?", isPresented: $showingRecurringDeleteOptions, titleVisibility: .visible) {
                Button("Delete Only This Event", role: .destructive) {
                    Task { await deleteEvent(span: .thisEvent) }
                }
                Button("Delete This and Future Events", role: .destructive) {
                    Task { await deleteEvent(span: .futureEvents) }
                }
                Button("Cancel", role: .cancel) { }
            }
            .onAppear {
                // Populate fields from existing event
                eventTitle = upcomingEvent.title
                startTime = upcomingEvent.startDate
                endTime = upcomingEvent.endDate
                eventDate = upcomingEvent.startDate
                locationAddress = upcomingEvent.location ?? ""
                isApplyingLocationSelection = true
                locationName = upcomingEvent.location ?? ""
                recurrenceConfig = RecurrenceConfiguration.none(anchor: upcomingEvent.startDate)
                if let rule = upcomingEvent.recurrenceRule,
                   let parsed = RecurrenceConfiguration.from(rule: rule, anchor: upcomingEvent.startDate) {
                    recurrenceConfig = parsed
                    repeatOption = parsed.suggestedRepeatOption(anchor: upcomingEvent.startDate)
                } else if upcomingEvent.hasRecurrence {
                    recurrenceConfig.isEnabled = true
                    repeatOption = .custom
                }

                // Fetch calendar ID from CoreData
                fetchCalendarId()

                // Fetch driver from CoreData
                fetchDriver()

                // Load existing alert from the saved event so edits keep prior value
                loadExistingAlertOption()

                // Clean up stale selected members (in case they were deleted)
                let validMemberIDs = Set(familyMembers.map { $0.objectID })
                selectedMemberCalendars = selectedMemberCalendars.filter { validMemberIDs.contains($0.key) }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Event Updated", isPresented: $showingSuccessMessage) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your event has been updated successfully!")
            }
            .alert("Event Deleted", isPresented: $showingDeleteSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your event has been deleted successfully!")
            }
            .tint(accentColor)
        }
    }

    private func fetchCalendarId() {
        // Use the calendar ID directly from the event (it comes from EventKit)
        calendarId = upcomingEvent.calendarID
    }

    private func attendeeInfoForNotification() -> (memberIds: [UUID], memberNames: [String]) {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        if let familyEvent = try? viewContext.fetch(fetchRequest).first,
           let attendees = familyEvent.attendees as? Set<FamilyMember>,
           !attendees.isEmpty {
            let ids = attendees.compactMap { $0.id }
            let names = attendees.compactMap { $0.name }
            return (ids, names)
        }

        // Fallback to all family members so calendar-only filters can still pass
        let ids = familyMembers.compactMap { $0.id }
        let names = familyMembers.compactMap { $0.name }
        return (ids, names)
    }

    private func selectedDriverName() -> String? {
        switch selectedDriver {
        case .regular(let driver):
            return driver.name
        case .familyMember(let member):
            return member.name
        case .none:
            return nil
        }
    }

    private func loadExistingAlertOption() {
        let ekEvent = CalendarManager.shared.fetchEventDetails(
            withIdentifier: upcomingEvent.id,
            occurrenceStartDate: upcomingEvent.startDate
        ) ?? CalendarManager.shared.fetchEventDetails(withIdentifier: upcomingEvent.id)

        guard let ekEvent else {
            alertOption = .none
            return
        }

        if let alarm = ekEvent.alarms?.first {
            alertOption = alertOption(from: alarm)
        } else {
            alertOption = .none
        }
    }

    private func alertOption(from alarm: EKAlarm) -> AlertOption {
        let minutesOffset = Int(alarm.relativeOffset / 60)
        switch minutesOffset {
        case 0:
            return .atTime
        case -15:
            return .fifteenMinsBefore
        case -60:
            return .oneHourBefore
        case -1440:
            return .oneDayBefore
        default:
            return .custom
        }
    }

    private func fetchDriver() {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let familyEvent = results.first, let driver = familyEvent.driver {
                // Check if this driver is linked to a family member
                if let familyMemberId = driver.familyMemberId {
                    // This is a family member driver - find the family member and wrap it
                    if let familyMember = familyMembers.first(where: { $0.id == familyMemberId }) {
                        selectedDriver = .familyMember(familyMember)
                    }
                } else {
                    // This is a regular driver
                    selectedDriver = .regular(driver)
                }

                // Load the travel time if this is a family member driver
                if driver.familyMemberId != nil {
                    driverTravelTimeMinutes = Int(driver.travelTimeMinutes)
                }
            }
        } catch {
            print("Failed to fetch driver for event: \(error.localizedDescription)")
        }
    }

    private func saveEvent() async {
        await MainActor.run {
            isSaving = true
            print("📝 Starting save event for: \(upcomingEvent.title)")
            print("   Event ID: \(upcomingEvent.id)")
            print("   Calendar ID: \(upcomingEvent.calendarID)")
        }

        // Ensure we have the calendar ID
        guard let calId = calendarId, !calId.isEmpty else {
            await MainActor.run {
                errorMessage = "Unable to determine which calendar this event is in. Please try again."
                showingError = true
                isSaving = false
            }
            return
        }

        let title = eventTitle.trimmingCharacters(in: .whitespaces)

        // Use startTime and endTime directly as they now contain the correct date and time
        let eventStartDate = startTime
        let eventEndDate = endTime

        print("📝 Event details:")
        print("   Title: \(title)")
        print("   Start: \(eventStartDate)")
        print("   End: \(eventEndDate)")
        print("   Location: \(locationAddress.isEmpty ? "(none)" : locationAddress)")

        let recurrenceRule = selectedRecurrenceRule(startDate: eventStartDate)
        let updateSpan: EKSpan = (upcomingEvent.hasRecurrence || recurrenceRule != nil) ? .futureEvents : .thisEvent

        let success = CalendarManager.shared.updateEvent(
            withIdentifier: upcomingEvent.id,
            occurrenceStartDate: upcomingEvent.startDate,
            in: calId,
            title: title,
            startDate: eventStartDate,
            endDate: eventEndDate,
            location: locationAddress.isEmpty ? nil : locationAddress,
            notes: notes.isEmpty ? nil : notes,
            isAllDay: isAllDay,
            recurrenceRule: recurrenceRule,
            updateRecurrence: true,
            span: updateSpan,
            alertOption: alertOption
        )

        if success {
            // Update CoreData record if needed
            updateFamilyEvent()

            // Refresh local notifications to mirror the new alert setting
            Task {
                await notificationManager.cancelEventNotifications(for: upcomingEvent.id)

                if alertOption != .none {
                    let attendeeInfo = attendeeInfoForNotification()
                    if notificationManager.shouldNotifyForEvent(
                        calendarId: calId,
                        memberIds: attendeeInfo.memberIds
                    ),
                       let ekEvent = CalendarManager.shared.getEvent(withIdentifier: upcomingEvent.id) {
                        notificationManager.scheduleEventNotification(
                            event: ekEvent,
                            alertOption: alertOption,
                            familyMembers: attendeeInfo.memberNames,
                            drivers: selectedDriverName()
                        )
                    }
                }
            }

            await MainActor.run {
                // Trigger haptic feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)

                // Show success message and auto-dismiss
                showingSuccessMessage = true
            }

            // Auto-dismiss after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                dismiss()
            }
        } else {
            await MainActor.run {
                errorMessage = "Failed to update event. The event may have been deleted or the calendar is no longer accessible. Please try refreshing and creating a new event."
                showingError = true
                isSaving = false
            }
        }
    }

    private func updateFamilyEvent() {
        print("🚗 updateFamilyEvent called for event: \(upcomingEvent.id)")
        print("   Selected driver: \(selectedDriver?.name ?? "nil")")

        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            print("   FamilyEvents found: \(results.count)")

            let familyEvent: FamilyEvent
            if let existing = results.first {
                familyEvent = existing
                print("   Updating existing FamilyEvent with ID: \(familyEvent.id?.uuidString ?? "nil")")
            } else {
                // Create a new FamilyEvent record for this event
                print("   No FamilyEvent found - creating new one")
                familyEvent = FamilyEvent(context: viewContext)
                familyEvent.id = UUID()
                familyEvent.eventGroupId = UUID()
                familyEvent.eventIdentifier = upcomingEvent.id
                familyEvent.calendarId = upcomingEvent.calendarID
                familyEvent.createdAt = Date()
                familyEvent.isSharedCalendarEvent = false
                print("   Created new FamilyEvent with ID: \(familyEvent.id?.uuidString ?? "nil")")
            }

            print("   Has changes before: \(viewContext.hasChanges)")

            // Update the modified event in CoreData
            familyEvent.createdAt = Date() // Update timestamp

            // Handle driver assignment
            if let driverWrapper = selectedDriver {
                switch driverWrapper {
                case .regular(let driver):
                    familyEvent.driver = driver
                    print("🚗 Assigned regular driver: \(driver.name ?? "Unknown")")

                case .familyMember(let member):
                    // Check if there's already a driver record for this family member
                    let driverFetchRequest = Driver.fetchRequest()
                    if let memberId = member.id {
                        driverFetchRequest.predicate = NSPredicate(format: "familyMemberId == %@", memberId as CVarArg)
                    }

                    if let existingDriver = try viewContext.fetch(driverFetchRequest).first {
                        // Use existing driver record
                        familyEvent.driver = existingDriver
                        print("🚗 Using existing driver record for family member: \(member.name ?? "Unknown")")
                    } else {
                        // Create a new driver record for this family member
                        let newDriver = Driver(context: viewContext)
                        newDriver.id = UUID()
                        newDriver.name = member.name ?? "Unknown"
                        newDriver.familyMemberId = member.id
                        familyEvent.driver = newDriver
                        print("🚗 Created new driver record for family member: \(member.name ?? "Unknown")")
                    }

                    // Update or create travel event
                    if let driver = familyEvent.driver {
                        updateTravelEvent(
                            for: member,
                            eventName: eventTitle,
                            eventStartTime: combineDateAndTime(date: eventDate, time: startTime),
                            travelTimeMinutes: driverTravelTimeMinutes,
                            driver: driver
                        )

                        // Update driver travel time
                        driver.travelTimeMinutes = Int16(driverTravelTimeMinutes)
                        print("🚗 Updated travel event for family member driver: \(member.name ?? "Unknown"), travel time: \(driverTravelTimeMinutes) min")
                    }
                }
            } else {
                // No driver selected - clear the driver
                familyEvent.driver = nil
            }

            print("   Driver assigned: \(familyEvent.driver?.name ?? "nil")")
            print("   Has changes after: \(viewContext.hasChanges)")

            try viewContext.save()
            print("✅ FamilyEvent saved successfully")

            // Verify the save
            if let saved = try viewContext.fetch(fetchRequest).first {
                print("✅ Verified: FamilyEvent driver is now \(saved.driver?.name ?? "nil")")
            }
        } catch {
            print("❌ Failed to update FamilyEvent record: \(error.localizedDescription)")
            let nsError = error as NSError
            print("   Error domain: \(nsError.domain)")
            print("   Error code: \(nsError.code)")
        }
    }

    private func updateTravelEvent(
        for familyMember: FamilyMember,
        eventName: String,
        eventStartTime: Date,
        travelTimeMinutes: Int,
        driver: Driver
    ) {
        // Get the family member's linked personal calendar
        guard let memberCalendars = familyMember.memberCalendars as? Set<FamilyMemberCalendar>,
              let personalCalendar = memberCalendars.first(where: { $0.isAutoLinked }),
              let calendarID = personalCalendar.calendarID else {
            print("❌ Travel Event: Could not find linked calendar for family member \(familyMember.name ?? "Unknown")")
            return
        }

        // Calculate travel event timing
        let travelEventStartTime = eventStartTime.addingTimeInterval(-Double(travelTimeMinutes) * 60)
        let travelEventEndTime = eventStartTime
        let travelEventTitle = "Travel to \(eventName)"

        // If there's an existing travel event, update it
        if let existingTravelEventId = driver.travelEventIdentifier, !existingTravelEventId.isEmpty {
            let success = CalendarManager.shared.updateEvent(
                withIdentifier: existingTravelEventId,
                occurrenceStartDate: travelEventStartTime,
                in: calendarID,
                title: travelEventTitle,
                startDate: travelEventStartTime,
                endDate: travelEventEndTime,
                location: nil,
                notes: "Travel time to \(eventName)"
            )

            if success {
                print("✈️ Travel event updated: '\(travelEventTitle)' on \(personalCalendar.calendarName ?? "Personal Calendar"), duration: \(travelTimeMinutes) min")
            } else {
                print("❌ Failed to update travel event")
            }
        } else {
            // Create a new travel event if one doesn't exist
            let travelEventId = CalendarManager.shared.createEvent(
                title: travelEventTitle,
                startDate: travelEventStartTime,
                endDate: travelEventEndTime,
                location: nil,
                notes: "Travel time to \(eventName)",
                in: calendarID
            )

            if let eventId = travelEventId {
                driver.travelEventIdentifier = eventId
                print("✈️ Travel event created: '\(travelEventTitle)' on \(personalCalendar.calendarName ?? "Personal Calendar"), duration: \(travelTimeMinutes) min")
            } else {
                print("❌ Failed to create travel event")
            }
        }
    }

    private func handleDeleteTap() {
        if upcomingEvent.hasRecurrence {
            showingRecurringDeleteOptions = true
        } else {
            showingDeleteConfirmation = true
        }
    }

    private func deleteEvent(span: EKSpan = .thisEvent) async {
        await MainActor.run {
            isSaving = true
            print("🗑️  Starting delete event for: \(upcomingEvent.title)")
            print("   Event ID: \(upcomingEvent.id)")
            print("   Calendar ID: \(upcomingEvent.calendarID)")
        }

        // Ensure we have the calendar ID
        let calId = calendarId ?? upcomingEvent.calendarID
        guard !calId.isEmpty else {
            await MainActor.run {
                errorMessage = "Unable to determine which calendar this event is in. Please try again."
                showingError = true
                isSaving = false
            }
            return
        }

        let success = CalendarManager.shared.deleteEvent(
            withIdentifier: upcomingEvent.id,
            occurrenceStartDate: upcomingEvent.startDate,
            from: calId,
            span: span
        )

        if success {
            // Delete from CoreData
            deleteFamilyEvent()

            await MainActor.run {
                // Trigger haptic feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)

                // Show success message and auto-dismiss
                showingDeleteSuccess = true
            }

            // Auto-dismiss after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                dismiss()
            }
        } else {
            await MainActor.run {
                errorMessage = "Failed to delete event. The event may have already been deleted or the calendar is no longer accessible."
                showingError = true
                isSaving = false
            }
        }
    }

    private func deleteFamilyEvent() {
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            for familyEvent in results {
                viewContext.delete(familyEvent)
            }
            try viewContext.save()
        } catch {
            print("Failed to delete FamilyEvent record: \(error.localizedDescription)")
            // Don't show error for this - the event was already deleted from the calendar
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)

        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second

        return calendar.date(from: combinedComponents) ?? date
    }

    private var calendarWithMondayAsFirstDay: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    // MARK: - Section Builders

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(sectionBorder, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Time")

            VStack(spacing: 0) {
                HStack {
                    Text("All-day")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(primaryTextColor)
                    Spacer()
                    Toggle("", isOn: $isAllDay)
                        .tint(accentColor)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 10)

                Divider().padding(.leading, 4)

                timeRow(
                    title: "Starts",
                    dateText: formattedDate(startTime),
                    timeText: formattedTime(startTime),
                    dateAction: {
                        withAnimation {
                            if showingStartDatePicker {
                                showingStartDatePicker = false
                            } else {
                                showingStartDatePicker = true
                                showingEndDatePicker = false
                                showingStartTimePicker = false
                                showingEndTimePicker = false
                            }
                        }
                    },
                    timeAction: {
                        withAnimation {
                            if showingStartTimePicker {
                                showingStartTimePicker = false
                            } else {
                                showingStartTimePicker = true
                                showingStartDatePicker = false
                                showingEndDatePicker = false
                                showingEndTimePicker = false
                            }
                        }
                    }
                )

                Divider().padding(.leading, 4)

                timeRow(
                    title: "Ends",
                    dateText: formattedDate(endTime),
                    timeText: formattedTime(endTime),
                    dateAction: {
                        withAnimation {
                            if showingEndDatePicker {
                                showingEndDatePicker = false
                            } else {
                                showingEndDatePicker = true
                                showingStartDatePicker = false
                                showingStartTimePicker = false
                                showingEndTimePicker = false
                            }
                        }
                    },
                    timeAction: {
                        withAnimation {
                            if showingEndTimePicker {
                                showingEndTimePicker = false
                            } else {
                                showingEndTimePicker = true
                                showingStartDatePicker = false
                                showingEndDatePicker = false
                                showingStartTimePicker = false
                            }
                        }
                    }
                )
                
                if showingStartDatePicker {
                    DatePicker(
                        "Select Start Date",
                        selection: $startTime,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .environment(\.calendar, calendarWithMondayAsFirstDay)
                    .onChange(of: startTime) { _, newValue in
                        // Update eventDate for recurrence anchor if needed
                        eventDate = newValue
                    }
                }
                
                if showingEndDatePicker {
                    DatePicker(
                        "Select End Date",
                        selection: $endTime,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .environment(\.calendar, calendarWithMondayAsFirstDay)
                }

                Divider().padding(.leading, 4)

                timeShowAsRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(cardBackground)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(sectionBorder, lineWidth: 1)
            )



            if showingStartTimePicker {
                DatePicker(
                    "Start Time",
                    selection: $startTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
            }

            if showingEndTimePicker {
                DatePicker(
                    "End Time",
                    selection: $endTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
            }
        }
    }

    private func timeRow(title: String,
                         dateText: String,
                         timeText: String,
                         dateAction: @escaping () -> Void,
                         timeAction: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(primaryTextColor)

            Spacer()

            pillButton(dateText, action: dateAction)
            pillButton(timeText, action: timeAction)
        }
        .padding(.vertical, 10)
    }

    private var timeShowAsRow: some View {
        HStack {
            Text("Show as")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(primaryTextColor)

            Spacer()

            Menu {
                ForEach(ShowAsOption.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        showAsOption = option
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(showAsOption.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(secondaryTextColor)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(chipBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }

    private func pillButton(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(primaryTextColor)
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(chipBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func currentRecurrenceConfiguration(anchorDate: Date) -> RecurrenceConfiguration? {
        if repeatOption == .custom {
            return recurrenceConfig.isEnabled ? recurrenceConfig : nil
        }

        if let quickConfig = RecurrenceConfiguration.quick(option: repeatOption, anchor: anchorDate), quickConfig.isEnabled {
            return quickConfig
        }

        return nil
    }

    private func recurrenceSummaryText(anchorDate: Date) -> String {
        guard let config = currentRecurrenceConfiguration(anchorDate: anchorDate) else {
            return "Does not repeat"
        }
        return config.summary(anchor: anchorDate)
    }

    private func selectedRecurrenceRule(startDate: Date) -> EKRecurrenceRule? {
        currentRecurrenceConfiguration(anchorDate: startDate)?.toRecurrenceRule(anchor: startDate)
    }

    private func handleRepeatSelection(_ option: RepeatOption) {
        switch option {
        case .custom:
            if let existing = currentRecurrenceConfiguration(anchorDate: eventDate) {
                recurrenceConfig = existing
            } else if !recurrenceConfig.isEnabled {
                recurrenceConfig = RecurrenceConfiguration.quick(option: .weekly, anchor: eventDate) ?? recurrenceConfig
            }
            repeatOption = .custom
            showingCustomRepeatSheet = true
        default:
            repeatOption = option
        }
    }

    private var repeatDetailLabel: String {
        switch repeatOption {
        case .custom: return "Custom pattern"
        case .none: return "Off"
        default: return "Quick repeat"
        }
    }

    @ViewBuilder
    private var repeatSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Repeat")

                Menu {
                    ForEach(RepeatOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            handleRepeatSelection(option)
                        }
                    }
                } label: {
                    HStack {
                        Text("Repeat")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                        Text(repeatOption.rawValue)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(secondaryTextColor)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(fieldBackground)
                    .cornerRadius(14)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recurrenceSummaryText(anchorDate: eventDate))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    Text(repeatDetailLabel)
                        .font(.system(size: 13))
                        .foregroundColor(secondaryTextColor)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(fieldBackground)
                )

                Button {
                    if let existing = currentRecurrenceConfiguration(anchorDate: eventDate) {
                        recurrenceConfig = existing
                    } else {
                        recurrenceConfig = RecurrenceConfiguration.quick(option: .weekly, anchor: eventDate) ?? recurrenceConfig
                    }
                    repeatOption = .custom
                    showingCustomRepeatSheet = true
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Custom repeat options")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(accentColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(accentColor.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingCustomRepeatSheet) {
            CustomRepeatView(
                recurrence: $recurrenceConfig,
                anchorDate: eventDate
            ) { updated in
                repeatOption = updated.isEnabled ? .custom : .none
            }
        }
    }

    @ViewBuilder
    private var alertSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Alert")

                Menu {
                    ForEach(AlertOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            alertOption = option
                        }
                    }
                } label: {
                    HStack {
                        Text("Alert")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                        Text(alertOption.rawValue)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(secondaryTextColor)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(fieldBackground)
                    .cornerRadius(14)
                }
            }
        }
    }

    @ViewBuilder
    private var calendarSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Calendar")

                if let member = getEventMember() {
                    memberCalendarSelector(for: member)
                } else {
                    Text("Calendar: \(upcomingEvent.calendarTitle)")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(primaryTextColor)
                }
            }
        }
    }

    @ViewBuilder
    private func memberCalendarSelector(for member: FamilyMember) -> some View {
        if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar>,
           !memberCalendars.isEmpty {
            let sortedCalendars = memberCalendars.sorted { cal1, cal2 in
                // Auto-linked calendar first
                if cal1.isAutoLinked && !cal2.isAutoLinked { return true }
                if !cal1.isAutoLinked && cal2.isAutoLinked { return false }
                // Then by name
                return (cal1.calendarName ?? "") < (cal2.calendarName ?? "")
            }

            Menu {
                ForEach(sortedCalendars, id: \.self) { calendar in
                    Button(action: {
                        updateSelectedCalendarForMember(member: member, calendar: calendar)
                    }) {
                        HStack {
                            Circle()
                                .fill(Color.fromHex(calendar.calendarColorHex ?? "#555555"))
                                .frame(width: 12, height: 12)
                            Text(calendar.calendarName ?? "Unknown")
                            if isCalendarSelectedForMember(member: member, calendar: calendar) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if let selectedCalendar = getSelectedCalendarForMember(member: member) {
                        Circle()
                            .fill(Color.fromHex(selectedCalendar.calendarColorHex ?? "#555555"))
                            .frame(width: 10, height: 10)
                        Text(selectedCalendar.calendarName ?? "Unknown")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(primaryTextColor)
                    } else {
                        Text("Select calendar")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(secondaryTextColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(secondaryTextColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(fieldBackground)
                .cornerRadius(12)
            }
        } else {
            Text("Calendar: \(upcomingEvent.calendarTitle)")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(primaryTextColor)
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeading("Notes")

                TextEditor(text: $notes)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(primaryTextColor)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(fieldBackground)
                    .cornerRadius(12)
                    .frame(height: 120)
            }
        }
    }

    // MARK: - Calendar Selection Helpers

    private func getEventMember() -> FamilyMember? {
        // Try to find which member this event belongs to
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let familyEvent = results.first {
                if let attendees = familyEvent.attendees as? Set<FamilyMember>, !attendees.isEmpty {
                    return attendees.first
                }
            }
        } catch {
            print("Error fetching event member: \(error.localizedDescription)")
        }

        return nil
    }

    private func updateSelectedCalendarForMember(member: FamilyMember, calendar: FamilyMemberCalendar) {
        if let calendarID = calendar.calendarID {
            selectedMemberCalendars[member.objectID] = calendarID
            calendarId = calendarID
        }
    }

    private func getSelectedCalendarForMember(member: FamilyMember) -> FamilyMemberCalendar? {
        if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar> {
            // Check if there's a manually selected calendar for this member
            if let selectedCalID = selectedMemberCalendars[member.objectID],
               let selected = memberCalendars.first(where: { $0.calendarID == selectedCalID }) {
                return selected
            }

            // Check if current event's calendar matches one of the member's calendars
            if let eventCalID = calendarId,
               let selected = memberCalendars.first(where: { $0.calendarID == eventCalID }) {
                return selected
            }

            // Otherwise return the first auto-linked calendar (predefined default)
            if let autoLinked = memberCalendars.first(where: { $0.isAutoLinked }) {
                return autoLinked
            }
            // If no auto-linked, return first calendar
            return memberCalendars.sorted { ($0.calendarName ?? "") < ($1.calendarName ?? "") }.first
        }
        return nil
    }

    private func isCalendarSelectedForMember(member: FamilyMember, calendar: FamilyMemberCalendar) -> Bool {
        if let selected = getSelectedCalendarForMember(member: member),
           selected.objectID == calendar.objectID {
            return true
        }
        return false
    }

    @ViewBuilder
    private var driverSection: some View {
        if !allAvailableDrivers.isEmpty {
            sectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Driver")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "car.fill")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(secondaryTextColor)
                            Text("Assign driver")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(primaryTextColor)
                            Spacer()
                            Menu {
                                Button(action: { selectedDriver = nil }) {
                                    HStack {
                                        Text("None")
                                        if selectedDriver == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Divider()
                                ForEach(allAvailableDrivers, id: \.id) { driverWrapper in
                                    Button(action: { selectedDriver = driverWrapper }) {
                                        HStack {
                                            Text(driverWrapper.name)
                                            if selectedDriver?.id == driverWrapper.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(selectedDriver?.name ?? "None")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(primaryTextColor)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(secondaryTextColor)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(fieldBackground)
                                .cornerRadius(10)
                            }
                        }

                        if let driver = selectedDriver, driver.isFamilyMember {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(secondaryTextColor)
                                Text("Travel Time")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(primaryTextColor)
                                Spacer()
                                Menu {
                                    ForEach([5, 10, 15, 20, 25, 30, 45, 60], id: \.self) { minutes in
                                        Button(action: { driverTravelTimeMinutes = minutes }) {
                                            HStack {
                                                Text("\(minutes) min")
                                                if driverTravelTimeMinutes == minutes {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("\(driverTravelTimeMinutes) min")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(primaryTextColor)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(secondaryTextColor)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(fieldBackground)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Title")

            HStack(spacing: 10) {
                TextField("Event Title", text: $eventTitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(primaryTextColor)

                Button(action: {}) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.93, green: 0.44, blue: 0.8),
                                Color(red: 0.99, green: 0.62, blue: 0.31),
                                Color(red: 0.73, green: 0.38, blue: 0.99)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
        }
    }


    @ViewBuilder
    private var locationSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("Location")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)

                    TextField("Location", text: $locationName)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(primaryTextColor)
                        .padding(10)
                        .background(fieldBackground)
                        .cornerRadius(10)
                        .onChange(of: locationName) { _, newValue in
                            if isApplyingLocationSelection {
                                isApplyingLocationSelection = false
                                return
                            }

                            searchCompleter.query = newValue
                            if newValue.isEmpty {
                                locationAddress = ""
                            }
                        }
                }

                if !searchCompleter.results.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(searchCompleter.results.enumerated()), id: \.offset) { index, result in
                            Button(action: {
                                isApplyingLocationSelection = true
                                locationName = result.title
                                locationAddress = result.subtitle
                                searchCompleter.query = ""
                                searchCompleter.results = []
                            }) {
                                locationSuggestion(result)
                            }
                            if index < searchCompleter.results.count - 1 {
                                Divider()
                                    .background(sectionBorder.opacity(0.4))
                            }
                        }
                    }
                    .background(fieldBackground)
                    .cornerRadius(12)
                }
            }
        }
    }

    @ViewBuilder
    private func locationSuggestion(_ result: MKLocalSearchCompletion) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(primaryTextColor)
            Text(result.subtitle)
                .font(.system(size: 12))
                .foregroundColor(secondaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

#Preview {
    let testEvent = UpcomingCalendarEvent(
        id: "123",
        title: "Team Meeting",
        location: "Conference Room",
        startDate: Date().addingTimeInterval(3600),
        endDate: Date().addingTimeInterval(7200),
        calendarID: "demo-calendar",
        calendarColor: UIColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1.0),
        calendarTitle: "Work",
        hasRecurrence: false, recurrenceRule: nil, isAllDay: false
    )

    EditEventView(upcomingEvent: testEvent)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
