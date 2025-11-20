//
//  AddSharedCalendarView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData
import EventKit

struct AddSharedCalendarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @FetchRequest(
        entity: SharedCalendar.entity(),
        sortDescriptors: []
    )
    private var sharedCalendars: FetchedResults<SharedCalendar>

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @State private var availableCalendars: [AvailableCalendar] = []
    @State private var isLoading = false

    var calendarsBySource: [String: [AvailableCalendar]] {
        Dictionary(grouping: availableCalendars) { $0.sourceTitle }
            .sorted { $0.key < $1.key }
            .reduce(into: [:]) { result, pair in
                result[pair.key] = pair.value.sorted { $0.title < $1.title }
            }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color(red: 0.33, green: 0.33, blue: 0.33))

                        Text("Loading calendars...")
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if availableCalendars.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)

                        Text("No calendars available")
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(Array(calendarsBySource.keys.sorted()), id: \.self) { sourceTitle in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(sourceTitle)
                                        .font(.system(size: 14, weight: .semibold, design: .default))
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 16)

                                    VStack(spacing: 0) {
                                        ForEach(calendarsBySource[sourceTitle] ?? [], id: \.id) { calendar in
                                            let isAlreadyAdded = sharedCalendars.contains { $0.calendarID == calendar.id }

                                            Button(action: {
                                                if !isAlreadyAdded {
                                                    addSharedCalendar(calendar)
                                                }
                                            }) {
                                                HStack(spacing: 12) {
                                                    Circle()
                                                        .fill(Color(uiColor: calendar.color))
                                                        .frame(width: 12, height: 12)

                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(calendar.title)
                                                            .font(.system(size: 16, weight: .semibold, design: .default))
                                                            .foregroundColor(.primary)
                                                    }

                                                    Spacer()

                                                    if isAlreadyAdded {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .font(.system(size: 20))
                                                            .foregroundColor(.green)
                                                    } else {
                                                        Image(systemName: "circle")
                                                            .font(.system(size: 20))
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .contentShape(Rectangle())
                                            }
                                            .disabled(isAlreadyAdded)

                                            if calendar.id != (calendarsBySource[sourceTitle] ?? []).last?.id {
                                                Divider()
                                                    .padding(.horizontal, 16)
                                            }
                                        }
                                    }
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .padding(.horizontal, 16)
                                }
                            }

                            Spacer()
                                .frame(height: 16)
                        }
                        .padding(.vertical, 16)
                    }
                }

                VStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(red: 0.33, green: 0.33, blue: 0.33))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Add Shared Calendar")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                }
            }
        }
        .onAppear {
            loadAvailableCalendars()
        }
    }

    private func loadAvailableCalendars() {
        isLoading = true
        Task { @MainActor in
            let calendars = CalendarManager.shared.fetchAvailableCalendars()
            availableCalendars = calendars
            isLoading = false
        }
    }

    private func addSharedCalendar(_ calendar: AvailableCalendar) {
        let newSharedCalendar = SharedCalendar(context: viewContext)
        newSharedCalendar.id = UUID()
        newSharedCalendar.calendarID = calendar.id
        newSharedCalendar.calendarName = calendar.title
        newSharedCalendar.calendarColorHex = calendar.color.hex()

        // Link shared calendar to all family members
        for member in familyMembers {
            newSharedCalendar.addToMembers(member)
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Error saving shared calendar: \(nsError), \(nsError.userInfo)")
        }
    }
}

#Preview {
    AddSharedCalendarView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
