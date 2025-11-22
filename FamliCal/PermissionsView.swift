//
//  PermissionsView.swift
//  FamliCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI
import EventKit
import Contacts
import UserNotifications

struct PermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var calendarPermissionStatus = ""
    @State private var contactsPermissionStatus = ""
    @State private var notificationPermissionStatus = ""
    @State private var showingPermissionAlert = false
    @State private var eventStore = EKEventStore()

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Calendar Permissions Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calendar Access")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                HStack(spacing: 16) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Calendar Permission")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)

                                        Text("Access to your calendar events")
                                            .font(.system(size: 13))
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    HStack(spacing: 6) {
                                        Text(getPermissionText())
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(getPermissionColor())
                                        
                                        Image(systemName: getPermissionIcon())
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(getPermissionColor())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        }

                        // Contacts Permissions Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contacts Access")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                HStack(spacing: 16) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Contacts Permission")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)

                                        Text("Quick add drivers from contacts")
                                            .font(.system(size: 13))
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    HStack(spacing: 6) {
                                        Text(getContactsPermissionText())
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(getContactsPermissionColor())

                                        Image(systemName: getContactsPermissionIcon())
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(getContactsPermissionColor())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        }

                        // Notifications Permissions Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifications")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                HStack(spacing: 16) {
                                    Image(systemName: "bell")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Notification Permission")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)

                                        Text("Reminders for events and activities")
                                            .font(.system(size: 13))
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    HStack(spacing: 6) {
                                        Text(getNotificationPermissionText())
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(getNotificationPermissionColor())

                                        Image(systemName: getNotificationPermissionIcon())
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(getNotificationPermissionColor())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        }

                        // Request Permission Buttons
                        VStack(spacing: 12) {
                            if getPermissionText() != "Granted" {
                                Button(action: requestCalendarPermission) {
                                    Text("Request Calendar Permission")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                            }

                            if getContactsPermissionText() != "Granted" {
                                Button(action: requestContactsPermission) {
                                    Text("Request Contacts Permission")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                            }

                            if getNotificationPermissionText() != "Granted" {
                                Button(action: requestNotificationPermission) {
                                    Text("Request Notification Permission")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Permission Info Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About Permissions")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                PermissionInfoRow(
                                    icon: "calendar",
                                    title: "Calendar Access",
                                    description: "FamliCal needs access to your device calendars to display family events, birthdays, and shared calendar events."
                                )
                                .padding(.bottom, 12)

                                Divider().padding(.leading, 40)

                                PermissionInfoRow(
                                    icon: "person.crop.circle.fill.badge.plus",
                                    title: "Contacts Access",
                                    description: "FamliCal needs access to your contacts to let you quickly add drivers from your contact list when creating events."
                                )
                                .padding(.vertical, 12)

                                Divider().padding(.leading, 40)

                                PermissionInfoRow(
                                    icon: "bell.badge",
                                    title: "Notifications",
                                    description: "FamliCal sends reminders before events to keep your family on schedule and alert you to last-minute changes."
                                )
                                .padding(.top, 12)
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Permissions")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Back")
                        }
                        .foregroundColor(.black)
                    }
                }
            }
        }
        .onAppear {
            checkCalendarPermission()
            checkContactsPermission()
            checkNotificationPermission()
        }
    }

    private func checkCalendarPermission() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized:
            calendarPermissionStatus = "Granted"
        case .denied:
            calendarPermissionStatus = "Denied"
        case .restricted:
            calendarPermissionStatus = "Restricted"
        case .notDetermined:
            calendarPermissionStatus = "Not Determined"
        case .fullAccess:
            calendarPermissionStatus = "Full Access"
        case .writeOnly:
            calendarPermissionStatus = "Write Only"
        @unknown default:
            calendarPermissionStatus = "Unknown"
        }
    }

    private func requestCalendarPermission() {
        eventStore.requestFullAccessToEvents { granted, _ in
            DispatchQueue.main.async {
                checkCalendarPermission()
            }
        }
    }

    private func getPermissionText() -> String {
        calendarPermissionStatus.isEmpty ? "Checking..." : calendarPermissionStatus
    }

    private func getPermissionIcon() -> String {
        switch calendarPermissionStatus {
        case "Granted":
            return "checkmark.circle.fill"
        case "Denied":
            return "xmark.circle.fill"
        case "Restricted":
            return "exclamationmark.circle.fill"
        case "Not Determined":
            return "questionmark.circle.fill"
        default:
            return "circle"
        }
    }

    private func getPermissionColor() -> Color {
        switch calendarPermissionStatus {
        case "Granted":
            return .green
        case "Denied", "Restricted":
            return .red
        case "Not Determined":
            return .orange
        default:
            return .gray
        }
    }

    private func checkContactsPermission() {
        let status = ContactsManager.shared.getContactsAuthorizationStatus()
        switch status {
        case .authorized, .limited:
            contactsPermissionStatus = "Granted"
        case .denied:
            contactsPermissionStatus = "Denied"
        case .restricted:
            contactsPermissionStatus = "Restricted"
        case .notDetermined:
            contactsPermissionStatus = "Not Determined"
        @unknown default:
            contactsPermissionStatus = "Unknown"
        }
    }

    private func requestContactsPermission() {
        Task {
            _ = await ContactsManager.shared.requestContactsAccess()
            await MainActor.run {
                checkContactsPermission()
            }
        }
    }

    private func getContactsPermissionText() -> String {
        contactsPermissionStatus.isEmpty ? "Checking..." : contactsPermissionStatus
    }

    private func getContactsPermissionIcon() -> String {
        switch contactsPermissionStatus {
        case "Granted":
            return "checkmark.circle.fill"
        case "Denied":
            return "xmark.circle.fill"
        case "Restricted":
            return "exclamationmark.circle.fill"
        case "Not Determined":
            return "questionmark.circle.fill"
        default:
            return "circle"
        }
    }

    private func getContactsPermissionColor() -> Color {
        switch contactsPermissionStatus {
        case "Granted":
            return .green
        case "Denied", "Restricted":
            return .red
        case "Not Determined":
            return .orange
        default:
            return .gray
        }
    }

    private func checkNotificationPermission() {
        Task {
            let granted = await notificationManager.checkNotificationPermission()
            await MainActor.run {
                notificationPermissionStatus = granted ? "Granted" : "Denied"
            }
        }
    }

    private func requestNotificationPermission() {
        Task {
            let granted = await notificationManager.requestNotificationPermission()
            await MainActor.run {
                notificationPermissionStatus = granted ? "Granted" : "Denied"
            }
        }
    }

    private func getNotificationPermissionText() -> String {
        notificationPermissionStatus.isEmpty ? "Checking..." : notificationPermissionStatus
    }

    private func getNotificationPermissionIcon() -> String {
        switch notificationPermissionStatus {
        case "Granted":
            return "checkmark.circle.fill"
        case "Denied":
            return "xmark.circle.fill"
        case "Restricted":
            return "exclamationmark.circle.fill"
        case "Not Determined":
            return "questionmark.circle.fill"
        default:
            return "circle"
        }
    }

    private func getNotificationPermissionColor() -> Color {
        switch notificationPermissionStatus {
        case "Granted":
            return .green
        case "Denied", "Restricted":
            return .red
        case "Not Determined":
            return .orange
        default:
            return .gray
        }
    }
}

private struct PermissionInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .lineLimit(nil)
            }

            Spacer()
        }
    }
}

#Preview {
    PermissionsView()
        .environmentObject(ThemeManager())
}
