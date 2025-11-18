//
//  AppSettingsView.swift
//  FamliCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("eventsPerPerson") private var eventsPerPerson: Int = 3
    @AppStorage("eventsPastDays") private var eventsPastDays: Int = 0
    @AppStorage("eventsFutureDays") private var eventsFutureDays: Int = 180
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval: Int = 5
    @AppStorage("defaultMapsApp") private var defaultMapsApp: String = "Apple Maps"

    private let mapsAppOptions = ["Apple Maps", "Google Maps", "Waze"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Number of Events Per Person Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next Events")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Events per person")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("How many upcoming events to show for each person")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Picker("Events", selection: $eventsPerPerson) {
                                    ForEach(1...10, id: \.self) { number in
                                        Text("\(number)").tag(number)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    // Event Date Range Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Event Date Range")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            // Past days
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Show past events")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("Days to look back in history")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
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
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider()
                                .padding(.horizontal, 16)

                            // Future days
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Look ahead")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("Days to look forward in the future")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
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
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    // Auto Refresh Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Auto Refresh")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Refresh interval")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("Minutes between auto-refresh")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                HStack(spacing: 12) {
                                    Button(action: {
                                        if autoRefreshInterval > 1 {
                                            autoRefreshInterval -= 1
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.blue)
                                    }

                                    Text("\(autoRefreshInterval)m")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .frame(width: 40, alignment: .center)

                                    Button(action: {
                                        if autoRefreshInterval < 60 {
                                            autoRefreshInterval += 1
                                        }
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    // Default Maps App Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Maps")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Default maps app")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    Text("App to use for location links")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Picker("Maps App", selection: $defaultMapsApp) {
                                    ForEach(mapsAppOptions, id: \.self) { app in
                                        Text(app).tag(app)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("App Settings")
                        .font(.system(size: 16, weight: .semibold))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

#Preview {
    AppSettingsView()
}
