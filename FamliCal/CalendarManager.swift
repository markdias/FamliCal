//
//  CalendarManager.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import EventKit
import EventKitUI
import UIKit

struct AvailableCalendar {
    let id: String
    let title: String
    let color: UIColor
    let sourceTitle: String  // Account name (e.g., "iCloud", "Gmail")
    let sourceType: EKSourceType
}

struct UpcomingCalendarEvent {
    let id: String
    let title: String
    let location: String?
    let startDate: Date
    let endDate: Date
    let calendarID: String
    let calendarColor: UIColor
    let calendarTitle: String
    let hasRecurrence: Bool
    let recurrenceRule: EKRecurrenceRule?
    let isAllDay: Bool
}
@MainActor
final class CalendarManager {
    static let shared = CalendarManager()

    private let eventStore = EKEventStore()

    func fetchAvailableCalendars() -> [AvailableCalendar] {
        let calendars = eventStore.calendars(for: .event)
        return calendars.map { calendar in
            let calendarColor: UIColor
            if let cgColor = calendar.cgColor {
                calendarColor = UIColor(cgColor: cgColor)
            } else {
                calendarColor = .systemBlue
            }

            return AvailableCalendar(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                color: calendarColor,
                sourceTitle: calendar.source.title,
                sourceType: calendar.source.sourceType
            )
        }
    }

    func findMatchingCalendar(for personName: String, in availableCalendars: [AvailableCalendar]) -> AvailableCalendar? {
        let lowercasedName = personName.lowercased()
        return availableCalendars.first { calendar in
            calendar.title.lowercased() == lowercasedName
        }
    }

    // MARK: - Private Helper Method for Robust Event Lookup

    private func findEvent(withIdentifier identifier: String, occurrenceStartDate: Date? = nil) -> EKEvent? {
        let calendars = eventStore.calendars(for: .event)

        if let occurrenceDate = occurrenceStartDate {
            // Tight search window around the specific occurrence start time
            let searchStart = occurrenceDate.addingTimeInterval(-300) // 5 min before
            let searchEnd = occurrenceDate.addingTimeInterval(300) // 5 min after
            let predicate = eventStore.predicateForEvents(
                withStart: searchStart,
                end: searchEnd,
                calendars: calendars
            )
            let matches = eventStore.events(matching: predicate)
            if let occurrence = matches.first(where: {
                $0.eventIdentifier == identifier &&
                abs($0.startDate.timeIntervalSince(occurrenceDate)) < 1
            }) {
                return occurrence
            }
        }

        // The event(withIdentifier:) method doesn't always work reliably, but try it next
        if let event = eventStore.event(withIdentifier: identifier) {
            // If we were looking for a specific occurrence, make sure the dates match before returning
            if let occurrenceDate = occurrenceStartDate {
                if abs(event.startDate.timeIntervalSince(occurrenceDate)) < 1 {
                    return event
                }
            } else {
                return event
            }
        }

        // Fallback: search through all event calendars
        for calendar in calendars {
            let predicate = eventStore.predicateForEvents(withStart: Date(timeIntervalSince1970: 0),
                                                           end: Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 86400 * 365 * 2),
                                                           calendars: [calendar])
            let events = eventStore.events(matching: predicate)
            if let event = events.first(where: {
                guard $0.eventIdentifier == identifier else { return false }
                if let occurrenceDate = occurrenceStartDate {
                    return abs($0.startDate.timeIntervalSince(occurrenceDate)) < 1
                }
                return true
            }) {
                return event
            }
        }

        return nil
    }

    func fetchEventDetails(withIdentifier identifier: String, occurrenceStartDate: Date? = nil) -> EKEvent? {
        return findEvent(withIdentifier: identifier, occurrenceStartDate: occurrenceStartDate)
    }

    func fetchNextEvents(for calendarIDs: [String], limit: Int) -> [UpcomingCalendarEvent] {
        let calendars = eventStore.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }

        // Get date range from user settings
        let pastDays = UserDefaults.standard.integer(forKey: "eventsPastDays")
        let futureDays = UserDefaults.standard.integer(forKey: "eventsFutureDays")

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -pastDays, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .day, value: futureDays, to: Date()) ?? Date()

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        var results: [UpcomingCalendarEvent] = []

        for event in events {
            let calendarColor = event.calendar.cgColor.map { UIColor(cgColor: $0) } ?? .systemBlue

            let upcomingEvent = UpcomingCalendarEvent(
                id: event.eventIdentifier,
                title: event.title,
                location: event.location,
                startDate: event.startDate,
                endDate: event.endDate,
                calendarID: event.calendar.calendarIdentifier,
                calendarColor: calendarColor,
                calendarTitle: event.calendar.title,
                hasRecurrence: event.hasRecurrenceRules,
                recurrenceRule: event.recurrenceRules?.first,
                isAllDay: event.isAllDay
            )
            results.append(upcomingEvent)

            if limit > 0 && results.count >= limit {
                break
            }
        }

        return results
    }

    func calculateRecurringOccurrences(startDate: Date, endDate: Date, recurrenceRule: EKRecurrenceRule?, upcomingEvents: [UpcomingCalendarEvent], currentEventId: String, eventTitle: String, limit: Int) -> [Date] {
        guard let rule = recurrenceRule else { return [] }

        var occurrences: [Date] = []
        let calendar = Calendar.current
        let duration = endDate.timeIntervalSince(startDate)

        // Find the next event with a DIFFERENT title chronologically
        let futureEvents = upcomingEvents.filter { $0.startDate > startDate && $0.title != eventTitle }
        let nextDifferentEvent = futureEvents.min { $0.startDate < $1.startDate }

        // Calculate end limit - either when the next different event occurs or 365 days out
        let endLimit = nextDifferentEvent?.startDate ?? calendar.date(byAdding: .day, value: 365, to: startDate) ?? startDate

        // Generate occurrences based on frequency
        var currentDate = startDate
        var count = 0

        while count < limit && currentDate < endLimit {
            // Calculate next occurrence date
            let nextOccurrence = getNextOccurrence(from: currentDate, using: rule)

            // If the occurrence end time would conflict with the next different event, stop
            let occurrenceEnd = nextOccurrence.addingTimeInterval(duration)
            if let nextEvent = nextDifferentEvent, occurrenceEnd > nextEvent.startDate {
                break
            }

            // Skip the first occurrence since it's shown as the header
            if nextOccurrence > startDate {
                occurrences.append(nextOccurrence)
                count += 1
            }

            currentDate = nextOccurrence
        }

        return occurrences
    }

    private func getNextOccurrence(from date: Date, using rule: EKRecurrenceRule) -> Date {
        let calendar = Calendar.current
        let interval = rule.interval

        switch rule.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date) ?? date
        @unknown default:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        }
    }

    func createEvent(title: String, startDate: Date, endDate: Date, location: String?, notes: String?, in calendarID: String) -> String? {
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("Error saving event: \(error.localizedDescription)")
            return nil
        }
    }

    func createRecurringEvent(title: String, startDate: Date, endDate: Date, location: String?, notes: String?, recurrenceRule: EKRecurrenceRule, in calendarID: String) -> String? {
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.addRecurrenceRule(recurrenceRule)
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .futureEvents)
            return event.eventIdentifier
        } catch {
            print("Error saving recurring event: \(error.localizedDescription)")
            return nil
        }
    }

    func updateEvent(withIdentifier identifier: String,
                     occurrenceStartDate: Date?,
                     in calendarID: String,
                     title: String,
                     startDate: Date,
                     endDate: Date,
                     location: String?,
                     notes: String?) -> Bool {
        // First, find the specific calendar
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else {
            print("❌ Could not find calendar with ID: \(calendarID)")
            return false
        }

        print("📍 Searching for event in calendar: \(calendar.title)")

        // Try to find the event using robust lookup (direct + fallback search)
        guard let event = findEvent(withIdentifier: identifier, occurrenceStartDate: occurrenceStartDate) else {
            print("❌ Could not find event with identifier: \(identifier) in calendar: \(calendar.title)")
            // List available calendars for debugging
            let allCals = eventStore.calendars(for: .event)
            print("   Available calendars: \(allCals.map { "\($0.title) (\($0.calendarIdentifier))" }.joined(separator: ", "))")
            return false
        }

        // Verify the event is in the correct calendar (safely access event.calendar)
        let eventCalendarID = event.calendar.calendarIdentifier
        guard eventCalendarID == calendarID else {
            print("❌ Event found but in wrong calendar!")
            print("   Expected calendar: \(calendarID)")
            print("   Actual calendar: \(eventCalendarID)")
            return false
        }

        print("✅ Found event: \(event.title ?? "Unknown") in calendar: \(event.calendar.title)")

        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes

        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ Event updated successfully")
            return true
        } catch {
            print("❌ Error updating event: \(error.localizedDescription)")
            // Log the underlying error details
            if let ekError = error as? EKError {
                print("   EKError code: \(ekError.errorCode)")
            }
            return false
        }
    }

    func deleteEvent(withIdentifier identifier: String,
                     occurrenceStartDate: Date?,
                     from calendarID: String,
                     span: EKSpan = .thisEvent) -> Bool {
        // First, find the specific calendar
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else {
            print("❌ Could not find calendar with ID: \(calendarID)")
            return false
        }

        print("📍 Searching for event to delete in calendar: \(calendar.title)")

        // Try to find the event using robust lookup (direct + fallback search)
        guard let event = findEvent(withIdentifier: identifier, occurrenceStartDate: occurrenceStartDate) else {
            print("❌ Could not find event to delete with identifier: \(identifier) in calendar: \(calendar.title)")
            // List available calendars for debugging
            let allCals = eventStore.calendars(for: .event)
            print("   Available calendars: \(allCals.map { "\($0.title) (\($0.calendarIdentifier))" }.joined(separator: ", "))")
            return false
        }

        // Verify the event is in the correct calendar (safely access event.calendar)
        let eventCalendarID = event.calendar.calendarIdentifier
        guard eventCalendarID == calendarID else {
            print("❌ Event found but in wrong calendar!")
            print("   Expected calendar: \(calendarID)")
            print("   Actual calendar: \(eventCalendarID)")
            return false
        }

        print("✅ Found event to delete: \(event.title ?? "Unknown") in calendar: \(event.calendar.title)")

        do {
            try eventStore.remove(event, span: span)
            print("✅ Event deleted successfully")
            return true
        } catch {
            print("❌ Error deleting event: \(error.localizedDescription)")
            // Log the underlying error details
            if let ekError = error as? EKError {
                print("   EKError code: \(ekError.errorCode)")
            }
            return false
        }
    }
}
