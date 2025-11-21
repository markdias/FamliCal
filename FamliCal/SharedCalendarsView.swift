//
//  SharedCalendarsView.swift
//  FamliCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import CoreData

struct SharedCalendarsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @FetchRequest(
        entity: SharedCalendar.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SharedCalendar.calendarName, ascending: true)]
    )
    private var sharedCalendars: FetchedResults<SharedCalendar>

    @State private var showingAddSharedCalendar = false

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Shared Calendars Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Shared Calendars")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            if sharedCalendars.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 48))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)

                                    Text("No shared calendars")
                                        .font(.system(size: 16, weight: .semibold, design: .default))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                    Text("Add calendars to share with all family members")
                                        .font(.system(size: 14, weight: .regular, design: .default))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                                .glassyCard(padding: 0)
                                .padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(sharedCalendars, id: \.self) { calendar in
                                        CalendarRow(
                                            title: calendar.calendarName ?? "Unknown",
                                            subtitle: "Shared with all",
                                            colorHex: calendar.calendarColorHex ?? "#007AFF",
                                            onDelete: {
                                                deleteSharedCalendar(calendar)
                                            }
                                        )

                                        if calendar.id != sharedCalendars.last?.id {
                                            Divider()
                                                .padding(.horizontal, 16)
                                                .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)
                                        }
                                    }
                                }
                                .glassyCard(padding: 0)
                                .padding(.horizontal, 16)
                            }

                            Button(action: { showingAddSharedCalendar = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)

                                    Text("Add Shared Calendar")
                                        .font(.system(size: 15, weight: .regular, design: .default))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .glassyCard(padding: 0)
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 16)
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
        .sheet(isPresented: $showingAddSharedCalendar) {
            AddSharedCalendarView()
                .environment(\.managedObjectContext, viewContext)
        }
    }

    private func deleteSharedCalendar(_ calendar: SharedCalendar) {
        viewContext.delete(calendar)

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Error deleting shared calendar: \(nsError), \(nsError.userInfo)")
        }
    }
}

#Preview {
    SharedCalendarsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
