//
//  PermissionsView.swift
//  FamliCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI
import EventKit
import Contacts

struct PermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var calendarPermissionStatus = ""
    @State private var contactsPermissionStatus = ""
    @State private var showingPermissionAlert = false
    @State private var eventStore = EKEventStore()

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Calendar Permissions Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Calendar Access")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            GlassyGridItem(action: {}) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Calendar Permission")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        Text("Access to your calendar events")
                                            .font(.system(size: 13))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }

                                    Spacer()

                                    HStack(spacing: 8) {
                                        Image(systemName: getPermissionIcon())
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(getPermissionColor())

                                        Text(getPermissionText())
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(getPermissionColor())
                                    }
                                }
                            }
                            .allowsHitTesting(false)
                            .padding(.horizontal, 16)
                        }

                        // Contacts Permissions Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Contacts Access")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            GlassyGridItem(action: {}) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Contacts Permission")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        Text("Quick add drivers from contacts")
                                            .font(.system(size: 13))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }

                                    Spacer()

                                    HStack(spacing: 8) {
                                        Image(systemName: getContactsPermissionIcon())
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(getContactsPermissionColor())

                                        Text(getContactsPermissionText())
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(getContactsPermissionColor())
                                    }
                                }
                            }
                            .allowsHitTesting(false)
                            .padding(.horizontal, 16)
                        }

                        // Permission Info Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("About Permissions")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 12) {
                                GlassyGridItem(action: {}) {
                                    PermissionInfoRow(
                                        icon: "calendar",
                                        title: "Calendar Access",
                                        description: "FamliCal needs access to your device calendars to display family events, birthdays, and shared calendar events."
                                    )
                                }
                                .allowsHitTesting(false)
                                .padding(.horizontal, 16)

                                GlassyGridItem(action: {}) {
                                    PermissionInfoRow(
                                        icon: "person.crop.circle.fill.badge.plus",
                                        title: "Contacts Access",
                                        description: "FamliCal needs access to your contacts to let you quickly add drivers from your contact list when creating events."
                                    )
                                }
                                .allowsHitTesting(false)
                                .padding(.horizontal, 16)
                            }
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
                        }
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Permissions")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? .white : .primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? .white : .blue)
                    }
                }
            }
        }
        .onAppear {
            checkCalendarPermission()
            checkContactsPermission()
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
}

private struct PermissionInfoRow: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
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
