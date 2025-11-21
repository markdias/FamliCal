//
//  SystemSettingsView.swift
//  FamliCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import CoreData

struct SystemSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            NavigationLink(destination: AppSettingsView()) {
                                SettingsMenuRow(
                                    iconName: "square.grid.2x2",
                                    iconColor: Color.blue,
                                    title: "App Settings",
                                    subtitle: "Default screen, refresh, maps"
                                )
                            }

                            NavigationLink(destination: ThemeSettingsView()) {
                                SettingsMenuRow(
                                    iconName: "paintbrush",
                                    iconColor: Color.purple,
                                    title: "Theme",
                                    subtitle: themeManager.selectedTheme.displayName
                                )
                            }

                            NavigationLink(destination: NotificationSettingsView().environment(\.managedObjectContext, viewContext)) {
                                SettingsMenuRow(
                                    iconName: "bell.fill",
                                    iconColor: Color.orange,
                                    title: "Notifications",
                                    subtitle: "Event alerts and morning brief"
                                )
                            }

                            NavigationLink(destination: PermissionsView()) {
                                SettingsMenuRow(
                                    iconName: "lock.fill",
                                    iconColor: Color.red,
                                    title: "Permissions",
                                    subtitle: "Calendar and contacts access"
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))

                            Text("Back")
                        }
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? .white : Color(red: 0.33, green: 0.33, blue: 0.33))
                    }
                }
            }
        }
    }
}

// MARK: - Settings Menu Row
private struct SettingsMenuRow: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
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

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
        }
        .glassyCard(padding: 0)
    }
}

#Preview {
    SystemSettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
