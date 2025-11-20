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
    @State private var showingFamilyMembers = false
    @State private var showingVisibleCalendars = false
    @State private var showingDrivers = false
    @State private var showingAppSettings = false
    @State private var showingPermissions = false
    @State private var showingThemeSettings = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 18) {
                        SettingsRowView(
                            iconName: "person.2.fill",
                            iconColor: Color.blue,
                            title: "Family Members",
                            subtitle: "Manage members and linked calendars",
                            action: { showingFamilyMembers = true }
                        )

                        SettingsRowView(
                            iconName: "calendar",
                            iconColor: Color.green,
                            title: "Visible Calendars",
                            subtitle: "Choose which calendars appear",
                            action: { showingVisibleCalendars = true }
                        )

                        SettingsRowView(
                            iconName: "car.fill",
                            iconColor: Color.orange,
                            title: "Drivers",
                            subtitle: "Manage drivers for events",
                            action: { showingDrivers = true }
                        )

                        SettingsRowView(
                            iconName: "paintbrush",
                            iconColor: Color.purple,
                            title: "Theme",
                            subtitle: themeManager.selectedTheme.displayName,
                            action: { showingThemeSettings = true }
                        )
                    }

                    VStack(alignment: .center, spacing: 8) {
                        Text("Layout & Localization")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)

                        HStack(spacing: 12) {
                            Button(action: { showingAppSettings = true }) {
                                SettingsCardView(
                                    iconName: "square.grid.2x2",
                                    title: "App Settings",
                                    subtitle: "Calendar grid, week start, events"
                                )
                            }
                            .buttonStyle(.plain)

                            SettingsCardView(
                                iconName: "rectangle.grid.2x2",
                                title: "Widget Settings",
                                subtitle: "Header placement, density, grid"
                            )
                        }
                    }

                    VStack(spacing: 12) {
                        Button(action: { showingPermissions = true }) {
                            SettingsRowView(
                                iconName: "lock.fill",
                                iconColor: Color.orange,
                                title: "Permissions",
                                subtitle: "Manage app access and permissions",
                                action: { showingPermissions = true }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
        .sheet(isPresented: $showingFamilyMembers) {
            FamilySettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingVisibleCalendars) {
            VisibleCalendarsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingDrivers) {
            DriversListView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAppSettings) {
            AppSettingsView()
        }
        .sheet(isPresented: $showingPermissions) {
            PermissionsView()
        }
        .sheet(isPresented: $showingThemeSettings) {
            ThemeSettingsView()
        }
    }
}

private struct SettingsRowView: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsCardView: View {
    let iconName: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .background(Color(.systemBlue).opacity(0.1))
                .cornerRadius(16)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
