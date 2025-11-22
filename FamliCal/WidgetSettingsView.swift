//
//  WidgetSettingsView.swift
//  FamliCal
//
//  Created by Claude Code
//

import SwiftUI

struct WidgetSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("widgetShowTime", store: UserDefaults(suiteName: "group.com.markdias.famli")) private var showTime: Bool = true
    @AppStorage("widgetShowLocation", store: UserDefaults(suiteName: "group.com.markdias.famli")) private var showLocation: Bool = true
    @AppStorage("widgetShowAttendees", store: UserDefaults(suiteName: "group.com.markdias.famli")) private var showAttendees: Bool = true
    @AppStorage("widgetShowDrivers", store: UserDefaults(suiteName: "group.com.markdias.famli")) private var showDrivers: Bool = true

    var body: some View {
        ZStack {
            Color(hex: "F2F2F7").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Family Events Widget Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Family Events Widget")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Event Time")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)

                                    Text("Show event start time")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Toggle("", isOn: $showTime)
                                    .tint(.blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().padding(.leading, 16)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Location")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)

                                    Text("Show event location")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Toggle("", isOn: $showLocation)
                                    .tint(.blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().padding(.leading, 16)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Attendees")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)

                                    Text("Show family members attending")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Toggle("", isOn: $showAttendees)
                                    .tint(.blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().padding(.leading, 16)

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Drivers")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)

                                    Text("Show assigned drivers")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Toggle("", isOn: $showDrivers)
                                    .tint(.blue)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }
                .padding(.vertical, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Widget Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
            }

            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Back")
                    }
                    .foregroundColor(.black)
                }
            }
        }
    }
}

#Preview {
    WidgetSettingsView()
}
