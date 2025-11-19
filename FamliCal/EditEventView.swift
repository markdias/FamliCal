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

    // Event details
    @State private var eventTitle: String = ""
    @State private var eventDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var notes: String = ""
    @State private var locationName: String = ""
    @State private var locationAddress: String = ""

    // Location search
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var isApplyingLocationSelection = false

    // Calendar info for updating
    @State private var calendarId: String? = nil

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
            Form {
                // Title Section
                Section {
                    TextField("Event Title", text: $eventTitle)
                        .font(.system(size: 17, weight: .regular))

                    // Location Section (under title, matching AddEventView)
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Add location", text: $locationName)
                            .font(.system(size: 16, weight: .regular))
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
                                    if index < searchCompleter.results.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                        }
                    }
                }

                // Date & Time Section (matching AddEventView)
                Section {
                    HStack {
                        Text("Starts")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Button(action: { showingDatePicker.toggle() }) {
                                Text(formattedDate(eventDate))
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            Button(action: { showingStartTimePicker.toggle() }) {
                                Text(formattedTime(startTime))
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.blue)
                            }
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

                    HStack {
                        Text("Ends")
                            .font(.system(size: 16, weight: .regular))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Button(action: { showingDatePicker.toggle() }) {
                                Text(formattedDate(eventDate))
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            Button(action: { showingEndTimePicker.toggle() }) {
                                Text(formattedTime(endTime))
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.blue)
                            }
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
                                Text("Save")
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
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let familyEvent = results.first {
                // Update the modified event in CoreData
                familyEvent.createdAt = Date() // Update timestamp
                try viewContext.save()
            }
        } catch {
            print("Failed to update FamilyEvent record: \(error.localizedDescription)")
            // Don't show error for this - the event was already updated in the calendar
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
