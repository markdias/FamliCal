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
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Shared Calendars Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Shared Calendars")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)

                            if sharedCalendars.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray)

                                    Text("No shared calendars")
                                        .font(.system(size: 16, weight: .semibold, design: .default))
                                        .foregroundColor(.primary)

                                    Text("Add calendars to share with all family members")
                                        .font(.system(size: 14, weight: .regular, design: .default))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
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
                                        }
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal, 16)
                            }

                            Button(action: { showingAddSharedCalendar = true }) {
                                Text("Add Shared Calendar")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Shared Calendars")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))

                            Text("Back")
                        }
                        .foregroundColor(.black)
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
