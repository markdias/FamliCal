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
                    VStack(spacing: 24) {
                        notificationsToggle

                        if notificationManager.notificationsEnabled {
                            morningBriefSection
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Notifications")
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
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Receive event notifications")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
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
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private var morningBriefSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.orange)
                            .cornerRadius(12)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Morning Brief")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)

                            Text("Daily event summary")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    Toggle("", isOn: $notificationManager.morningBriefEnabled)
                        .onChange(of: notificationManager.morningBriefEnabled) { _, _ in
                            notificationManager.saveSettings()
                            notificationManager.scheduleMorningBrief()
                        }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }

            if notificationManager.morningBriefEnabled {
                morningBriefTimePicker
            }
        }
    }

    private var morningBriefTimePicker: some View {
        VStack(spacing: 12) {
            Text("Notification Time")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)

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
                    .frame(height: 80)
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
                    .frame(height: 80)
                }
            }
            .padding(12)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
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
