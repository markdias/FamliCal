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
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var notificationManager = NotificationManager.shared
    @FetchRequest(entity: FamilyMember.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)])
    private var familyMembers: FetchedResults<FamilyMember>
    @State private var showingMemberSelection = false
    @State private var showingCalendarSelection = false

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(spacing: 24) {
                        notificationsToggle

                        if notificationManager.notificationsEnabled {
                            morningBriefSection
                            memberSelectionButton
                            calendarSelectionButton
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
        .sheet(isPresented: $showingMemberSelection) {
            NotificationMemberSelectionView(selectedMembers: $notificationManager.selectedMembersForNotifications)
        }
        .sheet(isPresented: $showingCalendarSelection) {
            NotificationCalendarSelectionView(selectedCalendars: $notificationManager.selectedCalendarsForNotifications)
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
            HStack {
                Text("Notification Time")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 8) {
                    Picker("Hour", selection: $notificationManager.morningBriefTime.hour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 60)

                    Text(":")
                        .font(.system(size: 14, weight: .semibold))

                    Picker("Minute", selection: $notificationManager.morningBriefTime.minute) {
                        ForEach(Array(stride(from: 0, to: 60, by: 15)), id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 60)
                }
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .onChange(of: notificationManager.morningBriefTime) { _, _ in
            notificationManager.saveSettings()
            notificationManager.scheduleMorningBrief()
        }
    }

    private var memberSelectionButton: some View {
        VStack(spacing: 12) {
            Button(action: { showingMemberSelection = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.33, green: 0.33, blue: 0.33))
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Family Members")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("\(notificationManager.selectedMembersForNotifications.count) selected")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    private var calendarSelectionButton: some View {
        VStack(spacing: 12) {
            Button(action: { showingCalendarSelection = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.green)
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calendars")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("\(notificationManager.selectedCalendarsForNotifications.count) selected")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NotificationSettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
