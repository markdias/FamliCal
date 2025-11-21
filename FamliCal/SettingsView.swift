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

    // Grid layout definition
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(spacing: 24) {
                        // Grid Settings
                        LazyVGrid(columns: columns, spacing: 16) {
                            SettingsGridItem(
                                iconName: "person.2.fill",
                                iconColor: Color(red: 0.33, green: 0.33, blue: 0.33),
                                title: "My Family",
                                subtitle: "Manage members",
                                action: { showingFamilySettings = true }
                            )

                            SettingsGridItem(
                                iconName: "square.grid.2x2.fill",
                                iconColor: Color.blue,
                                title: "App Settings",
                                subtitle: "General & Display",
                                action: { showingAppSettings = true }
                            )

                            SettingsGridItem(
                                iconName: "bell.fill",
                                iconColor: Color.orange,
                                title: "Notifications",
                                subtitle: "Alerts & Briefs",
                                action: { showingNotifications = true }
                            )

                            SettingsGridItem(
                                iconName: "lock.fill",
                                iconColor: Color.red,
                                title: "Permissions",
                                subtitle: "Privacy & Access",
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
            .navigationBarTitleDisplayMode(.inline)
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



private struct SettingsGridItem: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        GlassyGridItem(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(iconColor)
                    .cornerRadius(14)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
