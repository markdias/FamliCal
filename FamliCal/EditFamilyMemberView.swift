//
//  EditFamilyMemberView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData

struct EditFamilyMemberView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    let member: FamilyMember

    @State private var name = ""
    @State private var availableCalendars: [AvailableCalendar] = []
    @State private var matchedCalendar: AvailableCalendar? = nil
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Form content
                VStack(spacing: 24) {
                    // Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(.gray)

                        TextField("Enter family member's name", text: $name)
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onChange(of: name) { oldValue, newValue in
                                updateCalendarMatch()
                            }
                    }

                    // Calendar preview
                    if isLoading {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(.blue)

                            Text("Searching for calendar...")
                                .font(.system(size: 15, weight: .regular, design: .default))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    } else if let matched = matchedCalendar {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calendar Match")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundColor(.gray)

                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(uiColor: matched.color))
                                    .frame(width: 12, height: 12)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(matched.title)
                                        .font(.system(size: 15, weight: .semibold, design: .default))
                                        .foregroundColor(.primary)

                                    Text("This calendar will be linked to \(name)")
                                        .font(.system(size: 13, weight: .regular, design: .default))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    } else if !name.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calendar Match")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundColor(.gray)

                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 16))
                                    .foregroundColor(.orange)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("No calendar found")
                                        .font(.system(size: 15, weight: .semibold, design: .default))
                                        .foregroundColor(.primary)

                                    Text("No calendar matches '\(name)'")
                                        .font(.system(size: 13, weight: .regular, design: .default))
                                        .foregroundColor(.gray)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: saveMember) {
                        Text("Save Changes")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(name.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(name.isEmpty)

                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Edit Family Member")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                }
            }
        }
        .onAppear {
            name = member.name ?? ""
            loadAvailableCalendars()
        }
    }

    private func loadAvailableCalendars() {
        isLoading = true
        Task { @MainActor in
            let calendars = CalendarManager.shared.fetchAvailableCalendars()
            availableCalendars = calendars
            isLoading = false
            updateCalendarMatch()
        }
    }

    private func updateCalendarMatch() {
        guard !name.isEmpty else {
            matchedCalendar = nil
            return
        }

        matchedCalendar = CalendarManager.shared.findMatchingCalendar(for: name, in: availableCalendars)
    }

    private func saveMember() {
        member.name = name
        member.avatarInitials = getInitials(from: name)
        member.linkedCalendarID = matchedCalendar?.id

        // Handle auto-linked calendar updates
        let autoLinkedCal = (member.memberCalendars?.allObjects as? [FamilyMemberCalendar])?.first { $0.isAutoLinked }

        if let matched = matchedCalendar {
            // If the matched calendar is different from the current auto-linked one, update it
            if autoLinkedCal?.calendarID != matched.id {
                // Remove old auto-linked calendar if it exists
                if let oldCal = autoLinkedCal {
                    viewContext.delete(oldCal)
                }

                // Create new auto-linked calendar entry
                let memberCalendar = FamilyMemberCalendar(context: viewContext)
                memberCalendar.id = UUID()
                memberCalendar.calendarID = matched.id
                memberCalendar.calendarName = matched.title
                memberCalendar.calendarColorHex = matched.color.hex()
                memberCalendar.isAutoLinked = true
                memberCalendar.familyMember = member
            }
        } else {
            // No match found, remove auto-linked calendar if it exists
            if let oldCal = autoLinkedCal {
                viewContext.delete(oldCal)
            }
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            print("Error saving member: \(nsError), \(nsError.userInfo)")
        }
    }

    private func getInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].first ?? "?") + String(components[1].first ?? "?")
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let testMember = FamilyMember(context: context)
    testMember.id = UUID()
    testMember.name = "John Doe"
    testMember.colorHex = "#007AFF"
    testMember.avatarInitials = "JD"

    return EditFamilyMemberView(member: testMember)
        .environment(\.managedObjectContext, context)
}
