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

    // People selection
    @State private var selectedMembers: Set<NSManagedObjectID> = []
    @State private var selectEveryone = false

    // Location search
    @StateObject private var searchCompleter = LocationSearchCompleter()

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
        !eventTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        (!selectEveryone && !selectedMembers.isEmpty || selectEveryone) &&
        !selectedCalendarID.isEmpty
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
        NavigationView {
            Form {
                // Title Section
                Section {
                    TextField("Event Title", text: $eventTitle)
                        .font(.system(size: 17, weight: .regular))

                    // Location Section (under title)
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Add location", text: $locationName)
                            .font(.system(size: 16, weight: .regular))
                            .onChange(of: locationName) { _, newValue in
                                searchCompleter.query = newValue
                            }

                        if !searchCompleter.results.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(searchCompleter.results, id: \.self) { result in
                                    Button(action: {
                                        locationName = result.title
                                        locationAddress = result.subtitle
                                        searchCompleter.results = []
                                    }) {
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
                                    }
                                    Divider()
                                }
                            }
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                        }
                    }
                }

                // Date & Time Section
                Section {
                    HStack {
                        Text("Date")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        Button(action: { showingDatePicker.toggle() }) {
                            Text(formattedDate(eventDate))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.blue)
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

                    HStack {
                        Text("Starts")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        Button(action: { showingStartTimePicker.toggle() }) {
                            Text(formattedTime(startTime))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.blue)
                        }
                    }

                    if showingStartTimePicker {
                        DatePicker(
                            "Start Time",
                            selection: $startTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                    }

                    HStack {
                        Text("Ends")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        Button(action: { showingEndTimePicker.toggle() }) {
                            Text(formattedTime(endTime))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.blue)
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

                // People Section
                Section {
                    HStack {
                        Image(systemName: "person.2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Attendees")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        Button(action: {
                            withAnimation {
                                showingPeoplePicker.toggle()
                            }
                        }) {
                            Text(attendeesSummary)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                    }

                    if showingPeoplePicker {
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
                                        // Calendar color dot
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
                }

                // Calendar Section (only show if Everyone is selected and multiple shared calendars)
                if selectEveryone && availableCalendars.count > 1 {
                    Section {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Calendar")
                                .font(.system(size: 16, weight: .regular))
                            Spacer()
                            Button(action: { showingCalendarPicker.toggle() }) {
                                if let calendar = availableCalendars.first(where: { $0.calendarID == selectedCalendarID }) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(uiColor: calendar.color))
                                            .frame(width: 12, height: 12)
                                        Text(calendar.calendarName)
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.blue)
                                            .lineLimit(1)
                                    }
                                } else {
                                    Text("Select calendar")
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        if showingCalendarPicker {
                            ForEach(availableCalendars) { calendar in
                                Button(action: {
                                    selectedCalendarID = calendar.calendarID
                                    showingCalendarPicker = false
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(Color(uiColor: calendar.color))
                                            .frame(width: 16, height: 16)
                                        Text(calendar.calendarName)
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedCalendarID == calendar.calendarID {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Repeat Section
                Section {
                    HStack {
                        Image(systemName: "repeat")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 24)
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
                            Text(repeatOption.rawValue)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Alert Section
                Section {
                    HStack {
                        Image(systemName: "bell")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 24)
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
                            Text(alertOption.rawValue)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.blue)
                        }
                    }
                }

                // Notes Section
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .font(.system(size: 16, weight: .regular))
                        .frame(height: 100)
                }
            }
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
                            Text("Save")
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

        // Create event in the selected calendar
        let calendarID = selectedCalendarID
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

            // Add attendees for non-shared events
            if !selectEveryone {
                for memberID in selectedMembers {
                    if let member = familyMembers.first(where: { $0.objectID == memberID }) {
                        familyEvent.addToAttendees(member)
                    }
                }
            }
        }

        // Save CoreData changes and show success
        do {
            try viewContext.save()

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
}

enum RepeatOption: String, CaseIterable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"
}

enum AlertOption: String, CaseIterable {
    case none = "None"
    case atTime = "At time of event"
    case fifteenMinsBefore = "15 minutes before"
    case oneHourBefore = "1 hour before"
    case oneDayBefore = "1 day before"
    case custom = "Custom"
}

class LocationSearchCompleter: NSObject, ObservableObject {
    @Published var query: String = "" {
        didSet {
            searchCompleter.queryFragment = query
        }
    }
    @Published var results: [MKLocalSearchCompletion] = []

    private let searchCompleter = MKLocalSearchCompleter()

    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
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
