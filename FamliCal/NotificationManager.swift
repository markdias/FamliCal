//
//  NotificationManager.swift
//  FamliCal
//
//  Created by Mark Dias on 20/11/2025.
//

import Foundation
import Combine
import UserNotifications
import EventKit
import UIKit

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var notificationsEnabled = false
    @Published var morningBriefEnabled = false
    @Published var morningBriefTime = TimeComponents(hour: 8, minute: 0)
    @Published var selectedMembersForNotifications: Set<UUID> = []
    @Published var selectedCalendarsForNotifications: Set<String> = []

    private let userDefaults = UserDefaults.standard
    private let notificationCenter = UNUserNotificationCenter.current()

    // UserDefaults keys
    private let enabledKey = "notificationsEnabled"
    private let morningBriefEnabledKey = "morningBriefEnabled"
    private let morningBriefTimeKey = "morningBriefTime"
    private let selectedMembersKey = "selectedMembersForNotifications"
    private let selectedCalendarsKey = "selectedCalendarsForNotifications"

    override init() {
        super.init()
        loadSettings()
        notificationCenter.delegate = self
    }

    // MARK: - Permission Handling

    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.notificationsEnabled = granted
                if granted {
                    saveSettings()
                }
            }
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }

    func checkNotificationPermission() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Settings Management

    private func loadSettings() {
        notificationsEnabled = userDefaults.bool(forKey: enabledKey)
        morningBriefEnabled = userDefaults.bool(forKey: morningBriefEnabledKey)

        if let timeData = userDefaults.data(forKey: morningBriefTimeKey),
           let decoded = try? JSONDecoder().decode(TimeComponents.self, from: timeData) {
            morningBriefTime = decoded
        }

        if let membersData = userDefaults.data(forKey: selectedMembersKey),
           let decoded = try? JSONDecoder().decode([String].self, from: membersData) {
            selectedMembersForNotifications = Set(decoded.compactMap(UUID.init))
        }

        if let calendarsData = userDefaults.data(forKey: selectedCalendarsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: calendarsData) {
            selectedCalendarsForNotifications = Set(decoded)
        }
    }

    func saveSettings() {
        userDefaults.set(notificationsEnabled, forKey: enabledKey)
        userDefaults.set(morningBriefEnabled, forKey: morningBriefEnabledKey)

        if let encoded = try? JSONEncoder().encode(morningBriefTime) {
            userDefaults.set(encoded, forKey: morningBriefTimeKey)
        }

        let memberIds = selectedMembersForNotifications.map { $0.uuidString }
        if let encoded = try? JSONEncoder().encode(memberIds) {
            userDefaults.set(encoded, forKey: selectedMembersKey)
        }

        let calendars = Array(selectedCalendarsForNotifications)
        if let encoded = try? JSONEncoder().encode(calendars) {
            userDefaults.set(encoded, forKey: selectedCalendarsKey)
        }
    }

    // MARK: - Event Notification Scheduling

    func scheduleEventNotification(
        event: EKEvent,
        alertOption: AlertOption,
        familyMembers: [String],
        drivers: String?
    ) {
        guard notificationsEnabled else { return }

        let triggerDate = calculateTriggerDate(from: event.startDate, alertOption: alertOption)

        // Build notification content
        var title = event.title ?? "Event"
        if !familyMembers.isEmpty {
            title += " - \(familyMembers.joined(separator: ", "))"
        }

        var body = ""
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        body = timeFormatter.string(from: event.startDate)

        if let drivers = drivers, !drivers.isEmpty {
            body += "\nDriver: \(drivers)"
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [
            "eventIdentifier": event.eventIdentifier ?? "",
            "eventStart": event.startDate.timeIntervalSince1970
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: (event.eventIdentifier ?? UUID().uuidString) + "_" + UUID().uuidString,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }

    func cancelEventNotifications(for eventIdentifier: String) async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let identifiersToRemove = pending
            .filter { $0.identifier.starts(with: eventIdentifier) }
            .map { $0.identifier }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
    }

    // MARK: - Morning Brief

    func scheduleMorningBrief() {
        guard notificationsEnabled && morningBriefEnabled else {
            cancelMorningBrief()
            return
        }

        // Cancel existing morning brief first
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["morningBrief"])

        var components = DateComponents()
        components.hour = morningBriefTime.hour
        components.minute = morningBriefTime.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Good Morning"
        content.body = "Check your family's upcoming events for today"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "morningBrief", content: content, trigger: trigger)
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling morning brief: \(error)")
            }
        }
    }

    func cancelMorningBrief() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["morningBrief"])
    }

    // MARK: - Helper Methods

    private func calculateTriggerDate(from eventDate: Date, alertOption: AlertOption) -> Date {
        let calendar = Calendar.current

        switch alertOption {
        case .none:
            return eventDate
        case .atTime:
            return eventDate
        case .fifteenMinsBefore:
            return calendar.date(byAdding: .minute, value: -15, to: eventDate) ?? eventDate
        case .oneHourBefore:
            return calendar.date(byAdding: .hour, value: -1, to: eventDate) ?? eventDate
        case .oneDayBefore:
            return calendar.date(byAdding: .day, value: -1, to: eventDate) ?? eventDate
        case .custom:
            return eventDate
        }
    }

    func shouldNotifyForEvent(
        calendarId: String,
        memberIds: [UUID]
    ) -> Bool {
        // Check if calendar is selected
        guard selectedCalendarsForNotifications.contains(calendarId) else {
            return false
        }

        // Check if at least one member is selected
        return memberIds.contains { selectedMembersForNotifications.contains($0) }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Handle notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let eventIdentifier = userInfo["eventIdentifier"] as? String {
            // Navigate to event details
            NotificationCenter.default.post(
                name: NSNotification.Name("openEventDetail"),
                object: nil,
                userInfo: ["eventIdentifier": eventIdentifier]
            )
        }

        completionHandler()
    }
}

// MARK: - Time Components

struct TimeComponents: Codable, Hashable {
    var hour: Int
    var minute: Int

    func toDate() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }
}
