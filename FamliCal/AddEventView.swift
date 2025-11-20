//
//  AddEventView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import MapKit
import Combine
import EventKit
import CoreLocation

struct AddEventView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @FetchRequest(
        entity: SharedCalendar.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SharedCalendar.calendarName, ascending: true)]
    )
    private var sharedCalendars: FetchedResults<SharedCalendar>

    @FetchRequest(
        entity: Driver.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Driver.name, ascending: true)]
    )
    private var drivers: FetchedResults<Driver>

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
    @State private var repeatOption: RepeatOption = .none
    @State private var alertOption: AlertOption = .none
    @State private var notes: String = ""
    @State private var locationName: String = ""
    @State private var locationAddress: String = ""
    @State private var isAllDay: Bool = false
    @State private var showAsOption: ShowAsOption = .busy

    // People selection
    @State private var selectedMembers: Set<NSManagedObjectID> = []
    @State private var selectEveryone = false

    // Driver selection
    @State private var selectedDriver: DriverWrapper?
    @State private var driverTravelTimeMinutes: Int = 15

    // Location search
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var isApplyingLocationSelection = false

    // Permissions
    @State private var calendarAccessGranted = false
    @State private var showingPermissionAlert = false
    @State private var permissionErrorMessage = ""

    // UI state
    @State private var showingDatePicker = false
    @State private var showingStartTimePicker = false
    @State private var showingEndTimePicker = false
    @State private var showingRepeatPicker = false
    @State private var showingAlertPicker = false
    @State private var showingPeoplePicker = false
    @State private var isSaving = false
    @State private var showingSuccessMessage = false
    @State private var selectedCalendarID: String = ""
    @State private var availableCalendars: [CalendarOption] = []
    @State private var showingCalendarPicker = false

    var isFormValid: Bool {
        let hasTitle = !eventTitle.trimmingCharacters(in: .whitespaces).isEmpty
        let hasAttendees = (!selectEveryone && !selectedMembers.isEmpty) || selectEveryone
        let hasCalendar = selectEveryone ? !selectedCalendarID.isEmpty : true

        return hasTitle && hasAttendees && hasCalendar
    }

    struct CalendarOption: Identifiable {
        let id = UUID()
        let calendarID: String
        let calendarName: String
        let color: UIColor
    }

    var attendeesSummary: String {
        if selectEveryone {
            return "Everyone"
        }
        if selectedMembers.isEmpty {
            return "None"
        }
        let selected = familyMembers.filter { selectedMembers.contains($0.objectID) }
        let names = selected.map { $0.name ?? "Unknown" }
        return names.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleSection
                    locationSection
                    timeSection
                    attendeesSection
                    driverSection
                    showAsSection
                    repeatSection
                    alertSection
                    calendarSection
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
            .onAppear {
                // Request calendar permissions
                requestCalendarAccess()

                // Set default start and end times
                let calendar = Calendar.current
                let now = Date()
                var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
                components.hour = (components.hour ?? 0) + 1
                components.minute = 0

                startTime = calendar.date(from: components) ?? now.addingTimeInterval(3600)

                components.hour = (components.hour ?? 0) + 1
                endTime = calendar.date(from: components) ?? startTime.addingTimeInterval(3600)

                eventDate = now

                // Build available calendars list
                updateAvailableCalendars()
            }
            .onChange(of: selectEveryone) { _, _ in
                updateAvailableCalendars()
            }
            .onChange(of: selectedMembers) { _, _ in
                updateAvailableCalendars()
            }
            .alert("Calendar Access Required", isPresented: $showingPermissionAlert) {
                Button("OK") { }
            } message: {
                Text(permissionErrorMessage)
            }
            .alert("Event Created", isPresented: $showingSuccessMessage) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your event has been added successfully!")
            }
        }
    }

    private func updateAvailableCalendars() {
        availableCalendars = []
        var calendarSet = Set<String>() // To avoid duplicates

        if selectEveryone {
            // Show shared calendars for "Everyone"
            for calendar in sharedCalendars {
                if let calendarID = calendar.calendarID, !calendarSet.contains(calendarID) {
                    calendarSet.insert(calendarID)
                    let color = UIColor(displayP3Red: CGFloat.random(in: 0...1),
                                       green: CGFloat.random(in: 0...1),
                                       blue: CGFloat.random(in: 0...1),
                                       alpha: 1)
                    if let colorHex = calendar.calendarColorHex {
                        let parseColor = UIColor(named: colorHex) ?? UIColor(displayP3Red: 0.5, green: 0.5, blue: 1, alpha: 1)
                        availableCalendars.append(CalendarOption(
                            calendarID: calendarID,
                            calendarName: calendar.calendarName ?? "Shared Calendar",
                            color: parseColor
                        ))
                    } else {
                        availableCalendars.append(CalendarOption(
                            calendarID: calendarID,
                            calendarName: calendar.calendarName ?? "Shared Calendar",
                            color: color
                        ))
                    }
                }
            }
        } else {
            // Show selected members' calendars
            for memberID in selectedMembers {
                if let member = familyMembers.first(where: { $0.objectID == memberID }) {
                    if let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar> {
                        for memberCal in memberCalendars {
                            if let calendarID = memberCal.calendarID, !calendarSet.contains(calendarID) {
                                calendarSet.insert(calendarID)
                                let color = UIColor(named: memberCal.calendarColorHex ?? "#007AFF") ?? .blue
                                availableCalendars.append(CalendarOption(
                                    calendarID: calendarID,
                                    calendarName: memberCal.calendarName ?? (member.name ?? "Unknown"),
                                    color: color
                                ))
                            }
                        }
                    }
                }
            }
        }

        // Set default selection if not already set
        if selectedCalendarID.isEmpty && !availableCalendars.isEmpty {
            selectedCalendarID = availableCalendars.first?.calendarID ?? ""
        }
    }

    private func requestCalendarAccess() {
        let eventStore = EKEventStore()

        if #available(iOS 17, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    calendarAccessGranted = granted
                    if !granted {
                        permissionErrorMessage = "Calendar access is required to create events. Please enable it in Settings."
                        showingPermissionAlert = true
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    calendarAccessGranted = granted
                    if !granted {
                        permissionErrorMessage = "Calendar access is required to create events. Please enable it in Settings."
                        showingPermissionAlert = true
                    }
                }
            }
        }
    }

    private func createTravelEvent(
        for familyMember: FamilyMember,
        eventName: String,
        eventStartTime: Date,
        travelTimeMinutes: Int
    ) -> String? {
        // Get the family member's linked personal calendar
        guard let memberCalendars = familyMember.memberCalendars as? Set<FamilyMemberCalendar>,
              let personalCalendar = memberCalendars.first(where: { $0.isAutoLinked }),
              let calendarID = personalCalendar.calendarID else {
            print("❌ Travel Event: Could not find linked calendar for family member \(familyMember.name ?? "Unknown")")
            return nil
        }

        // Calculate travel event timing
        let travelEventStartTime = eventStartTime.addingTimeInterval(-Double(travelTimeMinutes) * 60)
        let travelEventEndTime = eventStartTime // Travel event ends when main event starts

        let travelEventTitle = "Travel to \(eventName)"

        // Create the travel event
        let travelEventId = CalendarManager.shared.createEvent(
            title: travelEventTitle,
            startDate: travelEventStartTime,
            endDate: travelEventEndTime,
            location: nil,
            notes: "Travel time to \(eventName)",
            in: calendarID
        )

        if let eventId = travelEventId {
            print("✈️ Travel event created: '\(travelEventTitle)' on \(personalCalendar.calendarName ?? "Personal Calendar"), duration: \(travelTimeMinutes) min, event ID: \(eventId)")
        } else {
            print("❌ Failed to create travel event for family member \(familyMember.name ?? "Unknown")")
        }

        return travelEventId
    }

    private func saveEvent() async {
        // Check permissions first
        guard calendarAccessGranted else {
            permissionErrorMessage = "Please enable calendar access in Settings to create events."
            showingPermissionAlert = true
            return
        }

        await MainActor.run {
        isSaving = true
        }

        let eventGroupId = UUID()
        let title = eventTitle.trimmingCharacters(in: .whitespaces)

        // Combine eventDate with startTime and endTime
        let eventStartDate = combineDateAndTime(date: eventDate, time: startTime)
        let eventEndDate = combineDateAndTime(date: eventDate, time: endTime)

        // Create recurrence rule if needed
        let recurrenceRule: EKRecurrenceRule? = createRecurrenceRule(from: repeatOption)

        var createdEventIds: [String] = []

        print("🚗 DEBUG: About to save event. selectedDriver = \(selectedDriver?.name ?? "nil")")

        // Determine which calendars to add the event to
        var targetCalendars: [String] = []

        if selectEveryone {
            // Everyone selected: use the selected shared calendar
            targetCalendars = [selectedCalendarID]
        } else {
            // Specific people selected: add to each person's first (main) calendar
            for memberID in selectedMembers {
                if let member = familyMembers.first(where: { $0.objectID == memberID }),
                   let memberCalendars = member.memberCalendars as? Set<FamilyMemberCalendar>,
                   let firstCal = memberCalendars.first,
                   let calendarID = firstCal.calendarID {
                    targetCalendars.append(calendarID)
                }
            }
        }

        // Create event in all target calendars
        for calendarID in targetCalendars {
            var eventId: String?

            if let recurrenceRule = recurrenceRule {
                eventId = CalendarManager.shared.createRecurringEvent(
                    title: title,
                    startDate: eventStartDate,
                    endDate: eventEndDate,
                    location: locationAddress.isEmpty ? nil : locationAddress,
                    notes: notes.isEmpty ? nil : notes,
                    recurrenceRule: recurrenceRule,
                    in: calendarID
                )
            } else {
                eventId = CalendarManager.shared.createEvent(
                    title: title,
                    startDate: eventStartDate,
                    endDate: eventEndDate,
                    location: locationAddress.isEmpty ? nil : locationAddress,
                    notes: notes.isEmpty ? nil : notes,
                    in: calendarID
                )
            }

            print("📅 Created event with ID: \(eventId ?? "nil") in calendar: \(calendarID)")

            if let eventId = eventId {
                createdEventIds.append(eventId)

                // Store in CoreData
                let familyEvent = FamilyEvent(context: viewContext)
                familyEvent.id = eventGroupId
                familyEvent.eventGroupId = eventGroupId
                familyEvent.eventIdentifier = eventId
                familyEvent.calendarId = calendarID
                familyEvent.createdAt = Date()
                familyEvent.isSharedCalendarEvent = selectEveryone

                // Add driver information
                if let driverWrapper = selectedDriver {
                    switch driverWrapper {
                    case .regular(let driver):
                        familyEvent.driver = driver
                        print("🚗 Added regular driver: \(driver.name ?? "Unknown")")

                    case .familyMember(let member):
                        // Create a new Driver record for this family member
                        let driver = Driver(context: viewContext)
                        driver.id = UUID()
                        driver.name = member.name ?? "Unknown"
                        driver.familyMemberId = member.id
                        familyEvent.driver = driver

                        // Create travel event for family member driver
                        let travelEventId = createTravelEvent(
                            for: member,
                            eventName: title,
                            eventStartTime: eventStartDate,
                            travelTimeMinutes: driverTravelTimeMinutes
                        )

                        // Update driver with travel event info
                        driver.travelEventIdentifier = travelEventId
                        driver.travelTimeMinutes = Int16(driverTravelTimeMinutes)
                        print("🚗 Created travel event for family member driver: \(member.name ?? "Unknown"), travel time: \(driverTravelTimeMinutes) min")
                    }
                }

                print("📝 Saving FamilyEvent: eventIdentifier=\(eventId), driver=\(familyEvent.driver?.name ?? "None")")
                print("   Driver object ID: \(familyEvent.driver?.objectID.debugDescription ?? "nil")")
                print("   Driver is in context: \(familyEvent.driver?.managedObjectContext != nil)")
                print("   FamilyEvent will have driver: \(familyEvent.driver != nil)")

                // Add attendees for non-shared events
                if !selectEveryone {
                    for memberID in selectedMembers {
                        if let member = familyMembers.first(where: { $0.objectID == memberID }) {
                            familyEvent.addToAttendees(member)
                        }
                    }
                }
            }
        }

        // Save CoreData changes and show success
        do {
            try viewContext.save()
            print("✅ CoreData saved successfully. Created \(createdEventIds.count) event(s)")

            // Verify the save by fetching back immediately
            let fetchRequest = FamilyEvent.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "eventIdentifier IN %@", createdEventIds)
            let saved = try viewContext.fetch(fetchRequest)
            print("📋 Verified: \(saved.count) FamilyEvent(s) saved to database")
            for event in saved {
                print("   - Event: \(event.eventIdentifier ?? "unknown"), Driver: \(event.driver?.name ?? "nil")")
            }

            // Trigger haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)

            // Show success message and auto-dismiss
            await MainActor.run {
                showingSuccessMessage = true
            }

            // Wait a bit before showing the alert, then auto-dismiss after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("Failed to save event: \(error.localizedDescription)")
            await MainActor.run {
                isSaving = false
            }
        }
    }

    private func createRecurrenceRule(from option: RepeatOption) -> EKRecurrenceRule? {
        switch option {
        case .none:
            return nil
        case .daily:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly:
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .monthly:
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        case .yearly:
            return EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        case .custom:
            // For custom, default to weekly for now
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
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
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Starts")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)

                            HStack(spacing: 12) {
                                Button(action: { showingDatePicker.toggle() }) {
                                    Text(formattedDate(eventDate))
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(6)
                                }

                                Button(action: { showingStartTimePicker.toggle() }) {
                                    Text(formattedTime(startTime))
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(10)
                                        .background(Color(.systemGray6))
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

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ends")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)

                            HStack(spacing: 12) {
                                Button(action: { showingDatePicker.toggle() }) {
                                    Text(formattedDate(eventDate))
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(6)
                                }

                                Button(action: { showingEndTimePicker.toggle() }) {
                                    Text(formattedTime(endTime))
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(10)
                                        .background(Color(.systemGray6))
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
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)
                }
            }
        }
    }

    @ViewBuilder
    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attendees")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.2")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                    Text("Attendees")
                        .font(.system(size: 16, weight: .regular))
                    Spacer()
                    Button(action: {
                        withAnimation {
                            showingPeoplePicker.toggle()
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)

                if showingPeoplePicker {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $selectEveryone.animation()) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 32, height: 32)
                                    .overlay(Text("👥").font(.system(size: 18)))
                                Text("Everyone")
                                    .font(.system(size: 16, weight: .regular))
                            }
                        }

                        if !selectEveryone {
                            ForEach(familyMembers, id: \.objectID) { member in
                                Toggle(isOn: Binding(
                                    get: { selectedMembers.contains(member.objectID) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedMembers.insert(member.objectID)
                                        } else {
                                            selectedMembers.remove(member.objectID)
                                        }
                                    }
                                )) {
                                    HStack(spacing: 12) {
                                        if let memberCals = member.memberCalendars as? Set<FamilyMemberCalendar>,
                                           let firstCal = memberCals.first,
                                           let colorHex = firstCal.calendarColorHex {
                                            Circle()
                                                .fill(Color.fromHex(colorHex))
                                                .frame(width: 12, height: 12)
                                        } else {
                                            Circle()
                                                .fill(Color.fromHex(member.colorHex ?? "#007AFF"))
                                                .frame(width: 12, height: 12)
                                        }
                                        Text(member.name ?? "Unknown")
                                            .font(.system(size: 16, weight: .regular))
                                    }
                                }
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
    private var calendarSection: some View {
        if selectEveryone && availableCalendars.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                HStack {
                    Text("Calendar")
                        .font(.system(size: 16, weight: .regular))
                    Spacer()
                    Menu {
                        ForEach(availableCalendars) { calendar in
                            Button(action: {
                                selectedCalendarID = calendar.calendarID
                            }) {
                                HStack {
                                    Circle()
                                        .fill(Color(uiColor: calendar.color))
                                        .frame(width: 12, height: 12)
                                    Text(calendar.calendarName)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(.primary)
                                    if selectedCalendarID == calendar.calendarID {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if let calendar = availableCalendars.first(where: { $0.calendarID == selectedCalendarID }) {
                                Circle()
                                    .fill(Color(uiColor: calendar.color))
                                    .frame(width: 12, height: 12)
                                Text(calendar.calendarName)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.black)
                            }
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
}


class LocationSearchCompleter: NSObject, ObservableObject {
    @Published var query: String = "" {
        didSet {
            searchCompleter.queryFragment = query
        }
    }
    @Published var results: [MKLocalSearchCompletion] = []

    private let searchCompleter = MKLocalSearchCompleter()
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]

        // Request location permission but don't restrict search region
        locationManager.requestWhenInUseAuthorization()

        // Note: Not setting a region allows MapKit to search globally
        // This enables searching by postcode, address, or location name worldwide
        // Results will naturally prioritize based on relevance and user location
    }
}

extension LocationSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.results = []
        }
    }
}

#Preview {
    AddEventView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
