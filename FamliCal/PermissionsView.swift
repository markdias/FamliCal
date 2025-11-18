//
//  PermissionsView.swift
//  FamliCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI
import EventKit

struct PermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var calendarPermissionStatus = ""
    @State private var showingPermissionAlert = false
    @State private var eventStore = EKEventStore()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Calendar Permissions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Calendar Access")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Calendar Permission")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("Access to your calendar events")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    // Permission Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About Permissions")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 12) {
                            PermissionInfoRow(
                                icon: "calendar",
                                title: "Calendar Access",
                                description: "FamliCal needs access to your device calendars to display family events, birthdays, and shared calendar events."
                            )
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    // Request Permission Button
                    if getPermissionText() != "Granted" {
                        VStack(spacing: 12) {
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
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Permissions")
                        .font(.system(size: 16, weight: .semibold))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear(perform: checkCalendarPermission)
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
}
