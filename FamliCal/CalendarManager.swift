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
    let calendarColor: UIColor
    let calendarTitle: String
    let hasRecurrence: Bool
    let recurrenceRule: EKRecurrenceRule?
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

        return events.prefix(limit).map { event in
            UpcomingCalendarEvent(
                id: event.eventIdentifier,
                title: event.title,
                location: event.location,
                startDate: event.startDate,
                endDate: event.endDate,
                calendarColor: UIColor(cgColor: event.calendar.cgColor),
                calendarTitle: event.calendar.title,
                hasRecurrence: event.hasRecurrenceRules,
                recurrenceRule: event.recurrenceRules?.first
            )
        }
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

    func updateEvent(withIdentifier identifier: String, in calendarID: String, title: String, startDate: Date, endDate: Date, location: String?, notes: String?) -> Bool {
        guard let event = eventStore.event(withIdentifier: identifier) else { return false }

        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes

        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            print("Error updating event: \(error.localizedDescription)")
            return false
        }
    }

    func deleteEvent(withIdentifier identifier: String, from calendarID: String) -> Bool {
        guard let event = eventStore.event(withIdentifier: identifier) else { return false }

        do {
            try eventStore.remove(event, span: .thisEvent)
            return true
        } catch {
            print("Error deleting event: \(error.localizedDescription)")
            return false
        }
    }
}
