//
//  EventDetailView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import EventKit

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let event: UpcomingCalendarEvent
    @State private var isEditing = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
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
                VStack(alignment: .leading, spacing: 20) {
                    // Event title
                    VStack(alignment: .leading, spacing: 12) {
                        Text(event.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(uiColor: event.calendarColor))
                                .frame(width: 12, height: 12)

                            Text(event.calendarTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Event details
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Date")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)

                                    Text(Self.dateFormatter.string(from: event.startDate))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                            } icon: {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Time")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)

                                    Text("\(Self.timeFormatter.string(from: event.startDate)) – \(Self.timeFormatter.string(from: event.endDate))")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                            } icon: {
                                Image(systemName: "clock")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                        }

                        if let location = event.location, !location.isEmpty {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Label {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Location")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.gray)

                                        Text(location)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(3)
                                    }
                                } icon: {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                }
                            }
                        }

                        if event.hasRecurrence {
                            Divider()

                            HStack(spacing: 12) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Recurring")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)

                                    Text("This event repeats")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                }

                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
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
        }
    }
}

#Preview {
    let testEvent = UpcomingCalendarEvent(
        id: "123",
        title: "Team Meeting",
        location: "Conference Room A",
        startDate: Date().addingTimeInterval(3600),
        endDate: Date().addingTimeInterval(7200),
        calendarColor: UIColor.blue,
        calendarTitle: "Work",
        hasRecurrence: true,
        recurrenceRule: EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
    )

    EventDetailView(event: testEvent)
}
