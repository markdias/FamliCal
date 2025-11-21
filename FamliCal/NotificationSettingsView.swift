//
//  NotificationSettingsView.swift
//  FamliCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI
import CoreData

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Notifications Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("General")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                notificationsToggle
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        }

                        if notificationManager.notificationsEnabled {
                            // Morning Brief Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Morning Brief")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 0) {
                                    morningBriefSection
                                }
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal, 16)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Notifications")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .cancellationAction) {
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
    }

    private var notificationsToggle: some View {
        HStack(spacing: 16) {
            Image(systemName: "bell.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text("Receive event notifications")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }

            Spacer()

            Toggle("", isOn: $notificationManager.notificationsEnabled)
                .onChange(of: notificationManager.notificationsEnabled) { _, newValue in
                    notificationManager.saveSettings()
                    if newValue {
                        Task {
                            _ = await notificationManager.requestNotificationPermission()
                        }
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var morningBriefSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Morning Brief")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    Text("Daily event summary")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Spacer()

                Toggle("", isOn: $notificationManager.morningBriefEnabled)
                    .onChange(of: notificationManager.morningBriefEnabled) { _, _ in
                        notificationManager.saveSettings()
                        notificationManager.scheduleMorningBrief()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if notificationManager.morningBriefEnabled {
                Divider().padding(.leading, 56)
                morningBriefTimePicker
            }
        }
    }

    private var morningBriefTimePicker: some View {
        VStack(spacing: 16) {
            Text("Notification Time")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Hour")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)

                    Picker("Hour", selection: $notificationManager.morningBriefTime.hour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }

                VStack(spacing: 8) {
                    Text("Minute")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)

                    Picker("Minute", selection: $notificationManager.morningBriefTime.minute) {
                        ForEach(Array(stride(from: 0, to: 60, by: 15)), id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
            }
        }
        .padding(16)
        .onChange(of: notificationManager.morningBriefTime) { _, _ in
            notificationManager.saveSettings()
            notificationManager.scheduleMorningBrief()
        }
    }

}

#Preview {
    NotificationSettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
