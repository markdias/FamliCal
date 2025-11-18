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
    @State private var showingSuccessMessage = false
    @State private var showingDeleteSuccess = false

    var isFormValid: Bool {
        !eventTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                // Title Section
                Section {
                    TextField("Event Title", text: $eventTitle)
                        .font(.system(size: 17, weight: .regular))
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

                // Location Section
                Section(header: Text("Location")) {
                    TextField("Search location", text: $locationName)
                        .font(.system(size: 16, weight: .regular))
                        .onChange(of: locationName) { _, newValue in
                            searchCompleter.query = newValue
                        }

                    if !searchCompleter.results.isEmpty {
                        ForEach(searchCompleter.results, id: \.self) { result in
                            Button(action: {
                                locationName = result.title
                                locationAddress = result.subtitle
                                searchCompleter.results = []
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(result.subtitle)
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                            }
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
                    HStack(spacing: 16) {
                        Button(action: { showingDeleteConfirmation = true }) {
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
            .confirmationDialog("Delete Event", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteEvent()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this event? This cannot be undone.")
            }
            .onAppear {
                // Populate fields from existing event
                eventTitle = upcomingEvent.title
                startTime = upcomingEvent.startDate
                endTime = upcomingEvent.endDate
                eventDate = upcomingEvent.startDate
                locationAddress = upcomingEvent.location ?? ""
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
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", upcomingEvent.id)

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let familyEvent = results.first {
                calendarId = familyEvent.calendarId
            } else {
                // If not found in FamilyEvent, it might be an event not created by us
                errorMessage = "Could not find event details. This event may not have been created through FamliCal."
                showingError = true
            }
        } catch {
            errorMessage = "Failed to fetch event: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func saveEvent() async {
        await MainActor.run {
        isSaving = true
        }

        // Ensure we have the calendar ID
        guard let calId = calendarId, !calId.isEmpty else {
            errorMessage = "Unable to determine which calendar this event is in. Please try again."
            showingError = true
            isSaving = false
            return
        }

        let title = eventTitle.trimmingCharacters(in: .whitespaces)

        let success = CalendarManager.shared.updateEvent(
            withIdentifier: upcomingEvent.id,
            in: calId,
            title: title,
            startDate: startTime,
            endDate: endTime,
            location: locationAddress.isEmpty ? nil : locationAddress,
            notes: notes.isEmpty ? nil : notes
        )

        if success {
            // Update CoreData record if needed
            updateFamilyEvent()

            // Trigger haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)

            // Show success message and auto-dismiss
            await MainActor.run {
                showingSuccessMessage = true
            }

            // Auto-dismiss after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                dismiss()
            }
        } else {
            errorMessage = "Failed to update event. Please try again."
            showingError = true
            isSaving = false
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

    private func deleteEvent() async {
        await MainActor.run {
        isSaving = true
        }

        // Ensure we have the calendar ID
        guard let calId = calendarId, !calId.isEmpty else {
            errorMessage = "Unable to determine which calendar this event is in. Please try again."
            showingError = true
            isSaving = false
            return
        }

        let success = CalendarManager.shared.deleteEvent(
            withIdentifier: upcomingEvent.id,
            from: calId
        )

        if success {
            // Delete from CoreData
            deleteFamilyEvent()

            // Trigger haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)

            // Show success message and auto-dismiss
            await MainActor.run {
                showingDeleteSuccess = true
            }

            // Auto-dismiss after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                dismiss()
            }
        } else {
            errorMessage = "Failed to delete event. Please try again."
            showingError = true
            isSaving = false
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
        hasRecurrence: false, recurrenceRule: nil
    )

    EditEventView(upcomingEvent: testEvent)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
