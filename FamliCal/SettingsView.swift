//
//  SettingsView.swift
//  FamliCal
//
//  Created by Codex on 20/11/2025.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingFamilySettings = false
    @State private var showingAppSettings = false
    @State private var showingNotifications = false
    @State private var showingPermissions = false

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 18) {
                            SettingsRowView(
                                iconName: "person.2.fill",
                                iconColor: Color(red: 0.33, green: 0.33, blue: 0.33),
                                title: "My Family",
                                subtitle: "Family members and calendars",
                                action: { showingFamilySettings = true }
                            )

                            SettingsRowView(
                                iconName: "square.grid.2x2",
                                iconColor: Color.blue,
                                title: "App Settings",
                                subtitle: "General, display, and calendars",
                                action: { showingAppSettings = true }
                            )

                            SettingsRowView(
                                iconName: "bell.fill",
                                iconColor: Color.orange,
                                title: "Notifications",
                                subtitle: "Event alerts and morning brief",
                                action: { showingNotifications = true }
                            )

                            SettingsRowView(
                                iconName: "lock.fill",
                                iconColor: Color.red,
                                title: "Permissions",
                                subtitle: "Calendar and contacts access",
                                action: { showingPermissions = true }
                            )
                        }
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? .white : .primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFamilySettings) {
            FamilySettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAppSettings) {
            AppSettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingNotifications) {
            NavigationView {
                NotificationSettingsView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $showingPermissions) {
            NavigationView {
                PermissionsView()
            }
        }
    }
}

private struct SettingsRowView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        GlassyRow(action: action) {
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(iconColor)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                }
            }
        }
    }
}


#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
