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
            GlassyBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Notifications Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("General")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)

                            notificationsToggle
                                .padding(.horizontal, 16)
                        }

                        if notificationManager.notificationsEnabled {
                            // Morning Brief Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Morning Brief")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)

                                morningBriefSection
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
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }

    private var notificationsToggle: some View {
        GlassyGridItem(action: {}) {
            HStack(spacing: 16) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.blue)
                    .cornerRadius(14)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifications")
                        .font(.system(size: 16, weight: .semibold))
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
        }
        .allowsHitTesting(true)
    }

    private var morningBriefSection: some View {
        VStack(spacing: 12) {
            GlassyGridItem(action: {}) {
                HStack(spacing: 16) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.orange)
                        .cornerRadius(14)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Morning Brief")
                            .font(.system(size: 16, weight: .semibold))
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
            }
            .allowsHitTesting(true)
            .padding(.horizontal, 16)

            if notificationManager.morningBriefEnabled {
                morningBriefTimePicker
                    .padding(.horizontal, 16)
            }
        }
    }

    private var morningBriefTimePicker: some View {
        GlassyGridItem(action: {}) {
            VStack(spacing: 16) {
                Text("Notification Time")
                    .font(.system(size: 14, weight: .semibold))
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
        }
        .allowsHitTesting(true)
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
