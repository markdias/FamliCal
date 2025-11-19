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

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
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
                // Try to fetch event details, but don't fail if we can't
                fetchEventDetails()

                // Load location map regardless of event details
                if let location = event.location, !location.isEmpty {
                    geocodeLocation(location)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func fetchEventDetails() {
        // Try to fetch full event details for alarms, but continue without them if not available
        // This prevents crashes if the event has been deleted or is inaccessible
        do {
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
        } catch {
            print("⚠️ Error fetching event details: \(error.localizedDescription)")
            // Continue without alarms - we can still display the basic event info
        }
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
