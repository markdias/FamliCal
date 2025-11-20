//
//  AppSettingsView.swift
//  FamliCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage("eventsPerPerson") private var eventsPerPerson: Int = 3
    @AppStorage("spotlightEventsPerPerson") private var spotlightEventsPerPerson: Int = 5
    @AppStorage("eventsPastDays") private var eventsPastDays: Int = 90
    @AppStorage("eventsFutureDays") private var eventsFutureDays: Int = 180
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval: Int = 5
    @AppStorage("defaultMapsApp") private var defaultMapsApp: String = "Apple Maps"
    @AppStorage("defaultHomeScreen") private var defaultHomeScreenRawValue: String = DefaultHomeScreen.family.rawValue

    private let mapsAppOptions = ["Apple Maps", "Google Maps", "Waze"]
    private let refreshIntervalOptions: [Int] = [1, 5, 10, 15, 30, 60]
    private var defaultHomeScreenBinding: Binding<DefaultHomeScreen> {
        Binding(
            get: { DefaultHomeScreen(rawValue: defaultHomeScreenRawValue) ?? .family },
            set: { defaultHomeScreenRawValue = $0.rawValue }
        )
    }

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Default Screen Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("App Start")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Default screen")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        Text("Choose where the app opens")
                                            .font(.system(size: 13))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }

                                    Spacer()

                                    Picker("Default Screen", selection: defaultHomeScreenBinding) {
                                        ForEach(DefaultHomeScreen.allCases) { option in
                                            Text(option.displayName).tag(option)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .glassyCard(padding: 0)
                            .padding(.horizontal, 16)
                        }

                        // Number of Events Per Person Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Next Events")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Events per person")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        Text("How many upcoming events to show for each person")
                                            .font(.system(size: 13))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }

                                    Spacer()

                                    Picker("Events", selection: $eventsPerPerson) {
                                        ForEach(1...10, id: \.self) { number in
                                            Text("\(number)").tag(number)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Spotlight events")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        Text("How many events to show in spotlight view")
                                            .font(.system(size: 13))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }

                                    Spacer()

                                    Picker("Spotlight", selection: $spotlightEventsPerPerson) {
                                        ForEach(1...15, id: \.self) { number in
                                            Text("\(number)").tag(number)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .glassyCard(padding: 0)
                            .padding(.horizontal, 16)
                        }

                        // Event Date Range Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Event Date Range")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                // Past days
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Show past events")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        Text("Days to look back in history")
                                            .font(.system(size: 13))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }

                                    Spacer()

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
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                Divider()
                                    .padding(.horizontal, 16)
                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                // Future days
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Look ahead")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        Text("Days to look forward in the future")
                                            .font(.system(size: 13))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }

                                    Spacer()

                                    Picker("Future Days", selection: $eventsFutureDays) {
                                        Text("1 Month").tag(30)
                                        Text("3 Months").tag(90)
                                        Text("6 Months").tag(180)
                                        Text("1 Year").tag(365)
                                        Text("2 Years").tag(730)
                                    }
                                    .pickerStyle(.menu)
                                    .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .glassyCard(padding: 0)
                            .padding(.horizontal, 16)
                        }

                        // Auto Refresh Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Auto Refresh")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Refresh interval")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        Text("Minutes between auto-refresh")
                                            .font(.system(size: 13))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }

                                    Spacer()

                                    Picker("Refresh Interval", selection: $autoRefreshInterval) {
                                        ForEach(refreshIntervalOptions, id: \.self) { option in
                                            Text(option == 1 ? "1 minute" : "\(option) minutes")
                                                .tag(option)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .glassyCard(padding: 0)
                            .padding(.horizontal, 16)
                        }

                        // Default Maps App Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Maps")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            VStack(spacing: 0) {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Default maps app")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        Text("App to use for location links")
                                            .font(.system(size: 13))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    }

                                    Spacer()

                                    Picker("Maps App", selection: $defaultMapsApp) {
                                        ForEach(mapsAppOptions, id: \.self) { app in
                                            Text(app).tag(app)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
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
}

#Preview {
    AppSettingsView()
        .environmentObject(ThemeManager())
}
