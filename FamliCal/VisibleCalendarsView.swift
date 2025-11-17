//
//  VisibleCalendarsView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData

struct VisibleCalendarsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @FetchRequest(
        entity: SharedCalendar.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SharedCalendar.calendarName, ascending: true)]
    )
    private var sharedCalendars: FetchedResults<SharedCalendar>

    @State private var showingAddSharedCalendar = false
    @State private var expandedMember: FamilyMember? = nil
    @State private var selectedMember: FamilyMember? = nil

    var linkedCalendars: [FamilyMember] {
        familyMembers.filter { ($0.memberCalendars?.count ?? 0) > 0 }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    Text("Visible")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    if linkedCalendars.isEmpty && sharedCalendars.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)

                            Text("No visible calendars")
                                .font(.system(size: 16, weight: .semibold, design: .default))
                                .foregroundColor(.primary)

                            Text("Add family members or shared calendars to see them here")
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            // Family Member Calendars
                            if !linkedCalendars.isEmpty {
                                Text("Family Members")
                                    .font(.system(size: 14, weight: .semibold, design: .default))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 0) {
                                    ForEach(linkedCalendars, id: \.self) { member in
                                        VStack(spacing: 0) {
                                            // Member row (clickable)
                                            Button(action: {
                                                if expandedMember?.id == member.id {
                                                    expandedMember = nil
                                                } else {
                                                    expandedMember = member
                                                }
                                            }) {
                                                HStack(spacing: 12) {
                                                    Circle()
                                                        .fill(Color.fromHex(member.colorHex ?? "#007AFF"))
                                                        .frame(width: 10, height: 10)

                                                    VStack(alignment: .leading, spacing: 2) {
                                                        HStack(spacing: 8) {
                                                            Text(member.name ?? "Unknown")
                                                                .font(.system(size: 16, weight: .semibold, design: .default))
                                                                .foregroundColor(.primary)

                                                            Text("(\((member.memberCalendars?.count) ?? 0))")
                                                                .font(.system(size: 14, weight: .regular, design: .default))
                                                                .foregroundColor(.gray)
                                                        }

                                                        Text("Family member")
                                                            .font(.system(size: 12, weight: .regular, design: .default))
                                                            .foregroundColor(.gray)
                                                    }

                                                    Spacer()

                                                    Image(systemName: expandedMember?.id == member.id ? "chevron.up" : "chevron.down")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.gray)
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)

                                            // Expanded content
                                            if expandedMember?.id == member.id, let memberCals = member.memberCalendars?.allObjects as? [FamilyMemberCalendar] {
                                                let sortedCals = memberCals.sorted { ($0.isAutoLinked && !$1.isAutoLinked) || ($0.isAutoLinked == $1.isAutoLinked && ($0.calendarName ?? "") < ($1.calendarName ?? "")) }

                                                Divider()
                                                    .padding(.horizontal, 16)

                                                VStack(spacing: 0) {
                                                    ForEach(sortedCals, id: \.self) { cal in
                                                        HStack(spacing: 12) {
                                                            Circle()
                                                                .fill(Color.fromHex(cal.calendarColorHex ?? "#007AFF"))
                                                                .frame(width: 8, height: 8)

                                                            VStack(alignment: .leading, spacing: 2) {
                                                                Text(cal.calendarName ?? "Unknown")
                                                                    .font(.system(size: 14, weight: .regular))
                                                                    .foregroundColor(.primary)
                                                            }

                                                            Spacer()

                                                            if cal.isAutoLinked {
                                                                Image(systemName: "lock.fill")
                                                                    .font(.system(size: 12))
                                                                    .foregroundColor(.gray)
                                                            }
                                                        }
                                                        .padding(.horizontal, 16)
                                                        .padding(.vertical, 10)
                                                        .opacity(cal.isAutoLinked ? 0.6 : 1.0)

                                                        if cal.id != sortedCals.last?.id {
                                                            Divider()
                                                                .padding(.horizontal, 16)
                                                        }
                                                    }
                                                }

                                                // Edit button in expanded section
                                                Button(action: { selectedMember = member }) {
                                                    HStack(spacing: 8) {
                                                        Image(systemName: "pencil.circle.fill")
                                                            .font(.system(size: 16))

                                                        Text("Select Calendars")
                                                            .font(.system(size: 14, weight: .semibold))
                                                    }
                                                    .foregroundColor(.blue)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                }
                                                .buttonStyle(.plain)
                                            }

                                            if member.id != linkedCalendars.last?.id {
                                                Divider()
                                                    .padding(.horizontal, 16)
                                            }
                                        }
                                    }
                                }
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }

                            // Shared Calendars
                            if !sharedCalendars.isEmpty {
                                Text("Shared Calendars")
                                    .font(.system(size: 14, weight: .semibold, design: .default))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 0) {
                                    ForEach(sharedCalendars, id: \.self) { calendar in
                                        CalendarRow(
                                            title: calendar.calendarName ?? "Unknown",
                                            subtitle: "Shared Family Calendar",
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
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }

                            // Add Shared Calendar Button
                            Button(action: { showingAddSharedCalendar = true }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)

                                    Text("Add Shared Calendar")
                                        .font(.system(size: 15, weight: .regular, design: .default))
                                        .foregroundColor(.blue)

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer()
                        .frame(height: 24)
                }
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))

                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSharedCalendar) {
            AddSharedCalendarView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $selectedMember) { member in
            SelectMemberCalendarsView(member: member)
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

// MARK: - CalendarRow View

struct CalendarRow: View {
    let title: String
    let subtitle: String
    let colorHex: String
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.fromHex(colorHex))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.gray)
            }

            Spacer()

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(.systemGray3))
                }
                .buttonStyle(.plain) // Use plain style to prevent the whole row from being tappable
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}


#Preview {
    VisibleCalendarsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
