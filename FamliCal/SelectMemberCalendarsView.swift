//
//  SelectMemberCalendarsView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData

struct SelectMemberCalendarsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    let member: FamilyMember

    @FetchRequest private var memberCalendars: FetchedResults<FamilyMemberCalendar>
    @FetchRequest(
        entity: SharedCalendar.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SharedCalendar.calendarName, ascending: true)]
    )
    private var sharedCalendars: FetchedResults<SharedCalendar>

    @State private var availableCalendars: [AvailableCalendar] = []
    @State private var isLoading = false

    init(member: FamilyMember) {
        self.member = member

        let fetchRequest = FamilyMemberCalendar.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "familyMember == %@", member)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \FamilyMemberCalendar.isAutoLinked, ascending: false),
            NSSortDescriptor(keyPath: \FamilyMemberCalendar.calendarName, ascending: true)
        ]
        _memberCalendars = FetchRequest(fetchRequest: fetchRequest)
    }

    var autoLinkedCalendar: FamilyMemberCalendar? {
        memberCalendars.first { $0.isAutoLinked }
    }

    var manualCalendars: [FamilyMemberCalendar] {
        memberCalendars.filter { !$0.isAutoLinked }
    }

    var calendarsBySource: [String: [AvailableCalendar]] {
        // Filter out calendars that are already added
        let addedCalendarIDs = Set(memberCalendars.compactMap { $0.calendarID })
        let unaddedCalendars = availableCalendars.filter { !addedCalendarIDs.contains($0.id) }

        return Dictionary(grouping: unaddedCalendars) { $0.sourceTitle }
            .sorted { $0.key < $1.key }
            .reduce(into: [:]) { result, pair in
                result[pair.key] = pair.value.sorted { $0.title < $1.title }
            }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Member info header
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.fromHex(member.colorHex ?? "#007AFF"))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Text(member.avatarInitials ?? "?")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name ?? "Unknown")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text("\(memberCalendars.count) calendar\(memberCalendars.count != 1 ? "s" : "")")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)

                        // Current calendars section
                        if !memberCalendars.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Linked Calendars")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 0) {
                                    if let autoLinked = autoLinkedCalendar {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(Color.fromHex(autoLinked.calendarColorHex ?? "#007AFF"))
                                                .frame(width: 12, height: 12)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(autoLinked.calendarName ?? "Unknown")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)

                                                HStack(spacing: 4) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.green)

                                                    Text("Auto-linked")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.gray)
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .opacity(0.6)

                                        if !manualCalendars.isEmpty {
                                            Divider()
                                                .padding(.horizontal, 16)
                                        }
                                    }

                                    ForEach(manualCalendars, id: \.self) { calendar in
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(Color.fromHex(calendar.calendarColorHex ?? "#007AFF"))
                                                .frame(width: 12, height: 12)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(calendar.calendarName ?? "Unknown")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)
                                            }

                                            Spacer()

                                            Button(action: { removeCalendar(calendar) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(Color(.systemGray3))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)

                                        if calendar.id != manualCalendars.last?.id {
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

                        // Shared calendars section
                        if !sharedCalendars.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Shared Calendars")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 0) {
                                    ForEach(sharedCalendars, id: \.self) { calendar in
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(Color.fromHex(calendar.calendarColorHex ?? "#007AFF"))
                                                .frame(width: 12, height: 12)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(calendar.calendarName ?? "Unknown")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)

                                                HStack(spacing: 4) {
                                                    Image(systemName: "person.2.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.blue)

                                                    Text("Shared with all")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.gray)
                                                }
                                            }

                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .opacity(0.6)

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
                        }

                        // Available calendars section
                        if isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.blue)

                                Text("Loading calendars...")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else if !calendarsBySource.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Add More Calendars")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)

                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(calendarsBySource.keys.sorted()), id: \.self) { sourceTitle in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(sourceTitle)
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(.gray)
                                                .padding(.horizontal, 16)
                                                .padding(.top, 12)

                                            VStack(spacing: 0) {
                                                ForEach(calendarsBySource[sourceTitle] ?? [], id: \.id) { calendar in
                                                    Button(action: { addCalendar(calendar) }) {
                                                        HStack(spacing: 12) {
                                                            Circle()
                                                                .fill(Color(uiColor: calendar.color))
                                                                .frame(width: 12, height: 12)

                                                            VStack(alignment: .leading, spacing: 2) {
                                                                Text(calendar.title)
                                                                    .font(.system(size: 16, weight: .semibold))
                                                                    .foregroundColor(.primary)
                                                            }

                                                            Spacer()

                                                            Image(systemName: "plus.circle.fill")
                                                                .font(.system(size: 20))
                                                                .foregroundColor(.blue)
                                                        }
                                                        .padding(.horizontal, 16)
                                                        .padding(.vertical, 12)
                                                        .contentShape(Rectangle())
                                                    }
                                                    .buttonStyle(.plain)

                                                    if calendar.id != (calendarsBySource[sourceTitle] ?? []).last?.id {
                                                        Divider()
                                                            .padding(.horizontal, 16)
                                                    }
                                                }
                                            }
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

                // Done button
                VStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
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
                    Text("Select Calendars")
                        .font(.system(size: 16, weight: .semibold))
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

    private func addCalendar(_ calendar: AvailableCalendar) {
        let newMemberCalendar = FamilyMemberCalendar(context: viewContext)
        newMemberCalendar.id = UUID()
        newMemberCalendar.calendarID = calendar.id
        newMemberCalendar.calendarName = calendar.title
        newMemberCalendar.calendarColorHex = calendar.color.hex()
        newMemberCalendar.isAutoLinked = false
        newMemberCalendar.familyMember = member

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Error adding calendar: \(nsError), \(nsError.userInfo)")
        }
    }

    private func removeCalendar(_ calendar: FamilyMemberCalendar) {
        viewContext.delete(calendar)

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Error removing calendar: \(nsError), \(nsError.userInfo)")
        }
    }
}

#Preview {
    let controller = PersistenceController.preview
    let context = controller.container.viewContext

    // Create a sample family member
    let member = FamilyMember(context: context)
    member.id = UUID()
    member.name = "John Doe"
    member.colorHex = "#007AFF"
    member.avatarInitials = "JD"

    return SelectMemberCalendarsView(member: member)
        .environment(\.managedObjectContext, context)
}
