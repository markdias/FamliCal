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
    @State private var alertOption: AlertOption = .none

    // Location search
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var isApplyingLocationSelection = false

    // Calendar info for updating
    @State private var calendarId: String? = nil

    // Driver selection
    @State private var selectedDriver: DriverWrapper?
    @State private var driverTravelTimeMinutes: Int = 15

    // UI state
    @State private var showingDatePicker = false
    @State private var showingStartTimePicker = false
    @State private var showingEndTimePicker = false
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingRecurringDeleteOptions = false
    @State private var showingSuccessMessage = false
    @State private var showingDeleteSuccess = false

    var isFormValid: Bool {
        !eventTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleSection
                    locationSection
                    timeSection
                    driverSection
                    showAsSection
                    repeatSection
                    alertSection
                    notesSection
                    Spacer()
                        .frame(height: 20)
                }
                .padding(16)
            }
            .background(Color(.systemGray6))
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

                // Fetch calendar ID from CoreData
                fetchCalendarId()

                // Fetch driver from CoreData
                fetchDriver()
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
        }
    }

    private func fetchCalendarId() {
        // Use the calendar ID directly from the event (it comes from EventKit)
        calendarId = upcomingEvent.calendarID
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

        // Combine date and time components properly
        let eventStartDate = combineDateAndTime(date: eventDate, time: startTime)
        let eventEndDate = combineDateAndTime(date: eventDate, time: endTime)

        print("📝 Event details:")
        print("   Title: \(title)")
        print("   Start: \(eventStartDate)")
        print("   End: \(eventEndDate)")
        print("   Location: \(locationAddress.isEmpty ? "(none)" : locationAddress)")

        let success = CalendarManager.shared.updateEvent(
            withIdentifier: upcomingEvent.id,
            occurrenceStartDate: upcomingEvent.startDate,
            in: calId,
            title: title,
            startDate: eventStartDate,
            endDate: eventEndDate,
            location: locationAddress.isEmpty ? nil : locationAddress,
            notes: notes.isEmpty ? nil : notes
        )

        if success {
            // Update CoreData record if needed
            updateFamilyEvent()

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
        formatter.dateFormat = "h:mm a"
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
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 12) {
                // All-day toggle
                HStack {
                    Text("All-day")
                        .font(.system(size: 16, weight: .regular))
                    Spacer()
                    Toggle("", isOn: $isAllDay)
                        .tint(.blue)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)

                // Starts
                if !isAllDay {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Starts")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)

                        HStack(spacing: 12) {
                            Button(action: { showingDatePicker.toggle() }) {
                                Text(formattedDate(eventDate))
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.black)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(6)
                            }

                            Button(action: { showingStartTimePicker.toggle() }) {
                                Text(formattedTime(startTime))
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.black)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(6)
                            }
                        }

                        if showingDatePicker {
                            DatePicker(
                                "Select Date",
                                selection: $eventDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .environment(\.calendar, calendarWithMondayAsFirstDay)
                        }

                        if showingStartTimePicker {
                            DatePicker(
                                "Start Time",
                                selection: $startTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)

                    // Ends
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ends")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)

                        HStack(spacing: 12) {
                            Button(action: { showingDatePicker.toggle() }) {
                                Text(formattedDate(eventDate))
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.black)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(6)
                            }

                            Button(action: { showingEndTimePicker.toggle() }) {
                                Text(formattedTime(endTime))
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.black)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(6)
                            }
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
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)
                }
            }
        }
    }

    @ViewBuilder
    private var showAsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Show as")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            HStack {
                Text("Show as")
                    .font(.system(size: 16, weight: .regular))
                Spacer()
                Menu {
                    ForEach(ShowAsOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            showAsOption = option
                        }
                    }
                } label: {
                    HStack {
                        Text(showAsOption.rawValue)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.black)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repeat")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            HStack {
                Text("Repeat")
                    .font(.system(size: 16, weight: .regular))
                Spacer()
                Menu {
                    ForEach(RepeatOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            repeatOption = option
                        }
                    }
                } label: {
                    HStack {
                        Text(repeatOption.rawValue)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.black)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var alertSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alert")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            HStack {
                Text("Alert")
                    .font(.system(size: 16, weight: .regular))
                Spacer()
                Menu {
                    ForEach(AlertOption.allCases, id: \.self) { option in
                        Button(option.rawValue) {
                            alertOption = option
                        }
                    }
                } label: {
                    HStack {
                        Text(alertOption.rawValue)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.black)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            TextEditor(text: $notes)
                .font(.system(size: 16, weight: .regular))
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .frame(height: 120)
        }
    }

    @ViewBuilder
    private var driverSection: some View {
        if !allAvailableDrivers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Driver")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "car.fill")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                        Text("Driver")
                            .font(.system(size: 16, weight: .regular))
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
                            HStack {
                                Text(selectedDriver?.name ?? "None")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.black)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)

                    if let driver = selectedDriver, driver.isFamilyMember {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                            Text("Travel Time")
                                .font(.system(size: 16, weight: .regular))
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
                                HStack {
                                    Text("\(driverTravelTimeMinutes) min")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(.black)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            TextField("Event Title", text: $eventTitle)
                .font(.system(size: 16, weight: .regular))
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Location", text: $locationName)
                    .font(.system(size: 16, weight: .regular))
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)
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
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(8)
                }
            }
        }
    }

    @ViewBuilder
    private func locationSuggestion(_ result: MKLocalSearchCompletion) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            Text(result.subtitle)
                .font(.system(size: 12))
                .foregroundColor(.gray)
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
        calendarColor: UIColor.blue,
        calendarTitle: "Work",
        hasRecurrence: false, recurrenceRule: nil, isAllDay: false
    )

    EditEventView(upcomingEvent: testEvent)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
