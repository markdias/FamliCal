//
//  AppSettingsView.swift
//  FamliCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI
import CoreData

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var themeManager: ThemeManager

    @AppStorage("autoRefreshInterval") private var autoRefreshInterval: Int = 5
    @AppStorage("defaultMapsApp") private var defaultMapsApp: String = "Apple Maps"
    @AppStorage("defaultHomeScreen") private var defaultHomeScreenRawValue: String = DefaultHomeScreen.family.rawValue

    @AppStorage("eventsPerPerson") private var eventsPerPerson: Int = 3
    @AppStorage("spotlightEventsPerPerson") private var spotlightEventsPerPerson: Int = 5
    @AppStorage("eventsPastDays") private var eventsPastDays: Int = 90
    @AppStorage("eventsFutureDays") private var eventsFutureDays: Int = 180
    @AppStorage("defaultAlertOption") private var defaultAlertOptionRawValue: String = AlertOption.none.rawValue

    private let mapsAppOptions = ["Apple Maps", "Google Maps", "Waze"]
    private let refreshIntervalOptions: [Int] = [1, 5, 10, 15, 30, 60]

    private var defaultHomeScreenBinding: Binding<DefaultHomeScreen> {
        Binding(
            get: { DefaultHomeScreen(rawValue: defaultHomeScreenRawValue) ?? .family },
            set: { defaultHomeScreenRawValue = $0.rawValue }
        )
    }

    private var defaultAlertBinding: Binding<AlertOption> {
        Binding(
            get: { AlertOption(rawValue: defaultAlertOptionRawValue) ?? .none },
            set: { defaultAlertOptionRawValue = $0.rawValue }
        )
    }

    private var darkModeBinding: Binding<Bool> {
        Binding(
            get: { themeManager.isDarkModeEnabled },
            set: { themeManager.setDarkMode($0) }
        )
    }

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - General Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("General")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                settingRow(
                                    title: "Default screen",
                                    subtitle: "Choose where the app opens",
                                    picker: AnyView(
                                        Picker("Default Screen", selection: defaultHomeScreenBinding) {
                                            ForEach(DefaultHomeScreen.allCases) { option in
                                                Text(option.displayName).tag(option)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                    )
                                )

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                settingRow(
                                    title: "Auto refresh interval",
                                    subtitle: "Minutes between auto-refresh",
                                    picker: AnyView(
                                        Picker("Refresh Interval", selection: $autoRefreshInterval) {
                                            ForEach(refreshIntervalOptions, id: \.self) { option in
                                                Text(option == 1 ? "1 minute" : "\(option) minutes")
                                                    .tag(option)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                    )
                                )

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                settingRow(
                                    title: "Default maps app",
                                    subtitle: "App to use for location links",
                                    picker: AnyView(
                                        Picker("Maps App", selection: $defaultMapsApp) {
                                            ForEach(mapsAppOptions, id: \.self) { app in
                                                Text(app).tag(app)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                    )
                                )

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                NavigationLink(destination: DriversListView().environment(\.managedObjectContext, viewContext)) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Drivers")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                            Text("Manage drivers for events")
                                                .font(.system(size: 13))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                            .glassyCard(padding: 0)
                            .padding(.horizontal, 16)
                        }

                        // MARK: - Display Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Display")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                NavigationLink(destination: ThemeSettingsView()) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Theme")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                            Text(themeManager.selectedTheme.displayName)
                                                .font(.system(size: 13))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Dark mode")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        Text("Apply dark colors to current theme")
                                            .font(.system(size: 13))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }

                                    Spacer()

                                    Toggle("", isOn: darkModeBinding)
                                        .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .glassyCard(padding: 0)
                            .padding(.horizontal, 16)
                        }

                        // MARK: - Event Settings Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Event Settings")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                settingRow(
                                    title: "Events per person",
                                    subtitle: "How many upcoming events to show",
                                    picker: AnyView(
                                        Picker("Events", selection: $eventsPerPerson) {
                                            ForEach(1...10, id: \.self) { number in
                                                Text("\(number)").tag(number)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                    )
                                )

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                settingRow(
                                    title: "Spotlight events",
                                    subtitle: "Events to show in spotlight view",
                                    picker: AnyView(
                                        Picker("Spotlight", selection: $spotlightEventsPerPerson) {
                                            ForEach(1...15, id: \.self) { number in
                                                Text("\(number)").tag(number)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                    )
                                )

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                settingRow(
                                    title: "Default alert",
                                    subtitle: "Alert time for new events",
                                    picker: AnyView(
                                        Picker("Default Alert", selection: defaultAlertBinding) {
                                            ForEach(AlertOption.allCases, id: \.self) { option in
                                                Text(option.rawValue).tag(option)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                    )
                                )

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                settingRow(
                                    title: "Show past events",
                                    subtitle: "Days to look back",
                                    picker: AnyView(
                                        Picker("Past Days", selection: $eventsPastDays) {
                                            Text("None").tag(0)
                                            Text("1 Month").tag(30)
                                            Text("2 Months").tag(60)
                                            Text("3 Months").tag(90)
                                            Text("6 Months").tag(180)
                                            Text("1 Year").tag(365)
                                        }
                                        .pickerStyle(.menu)
                                        .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                    )
                                )

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                settingRow(
                                    title: "Look ahead",
                                    subtitle: "Days to look forward",
                                    picker: AnyView(
                                        Picker("Future Days", selection: $eventsFutureDays) {
                                            Text("1 Month").tag(30)
                                            Text("3 Months").tag(90)
                                            Text("6 Months").tag(180)
                                            Text("1 Year").tag(365)
                                            Text("2 Years").tag(730)
                                        }
                                        .pickerStyle(.menu)
                                        .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                    )
                                )
                            }
                            .glassyCard(padding: 0)
                            .padding(.horizontal, 16)
                        }

                        // MARK: - Calendar Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calendar")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                NavigationLink(destination: SharedCalendarsView().environment(\.managedObjectContext, viewContext)) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Shared calendars")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                            Text("Calendars shared with all members")
                                                .font(.system(size: 13))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                NavigationLink(destination: SavedAddressesSettingsView().environment(\.managedObjectContext, viewContext)) {
                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Saved places")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                            Text("Manage favorite locations")
                                                .font(.system(size: 13))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                            .glassyCard(padding: 0)
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("App Settings")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? .white : .primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? .white : Color(red: 0.33, green: 0.33, blue: 0.33))
                    }
                }
            }
        }
    }

    private func settingRow<V: View>(title: String, subtitle: String, picker: V) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
            }

            Spacer()

            picker
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    AppSettingsView()
        .environmentObject(ThemeManager())
}
