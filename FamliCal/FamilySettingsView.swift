//
//  FamilySettingsView.swift
//  FamliCal
//
//  Created by Mark Dias on 21/11/2025.
//

import SwiftUI
import CoreData

struct FamilySettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @State private var showingAddMember = false
    @State private var editingMember: FamilyMember? = nil
    @State private var spotlightMember: FamilyMember? = nil
    @State private var expandedMember: FamilyMember? = nil
    @State private var selectedMember: FamilyMember? = nil

    private var linkedCalendars: [FamilyMember] {
        familyMembers.filter { ($0.memberCalendars?.count ?? 0) > 0 }
    }

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // MARK: - Family Members Section
                        familyMembersSection

                        Spacer()
                    }
                    .padding(.vertical, 24)
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
        .sheet(isPresented: $showingAddMember) {
            AddFamilyMemberView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $editingMember) { member in
            EditFamilyMemberView(member: member)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $spotlightMember) { member in
            SpotlightView(member: member)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $selectedMember) { member in
            SelectMemberCalendarsView(member: member)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    private func deleteMember(_ member: FamilyMember) {
        viewContext.delete(member)

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Error deleting family member: \(nsError), \(nsError.userInfo)")
        }
    }

    // MARK: - Family Members Section
    private var familyMembersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Family Members")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                .padding(.horizontal, 16)

            if familyMembers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 48))
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)

                    Text("No family members yet")
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .glassyCard(padding: 0)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 12) {
                    ForEach(linkedCalendars, id: \.self) { member in
                        GlassyGridItem(action: {
                            withAnimation {
                                if expandedMember?.id == member.id {
                                    expandedMember = nil
                                } else {
                                    expandedMember = member
                                }
                            }
                        }) {
                            VStack(spacing: 0) {
                                HStack(spacing: 16) {
                                    if let firstCalendar = (member.memberCalendars?.allObjects as? [FamilyMemberCalendar])?.first {
                                        Circle()
                                            .fill(Color.fromHex(firstCalendar.calendarColorHex ?? "#007AFF"))
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Circle()
                                            .fill(Color.gray)
                                            .frame(width: 16, height: 16)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(member.name ?? "Unknown")
                                            .font(.system(size: 16, weight: .semibold, design: .default))
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                                        HStack(spacing: 4) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)

                                            Text("\((member.memberCalendars?.count) ?? 0) calendar\((member.memberCalendars?.count) ?? 0 != 1 ? "s" : "")")
                                                .font(.system(size: 13, weight: .regular, design: .default))
                                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: expandedMember?.id == member.id ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                }
                                .padding(.bottom, expandedMember?.id == member.id ? 16 : 0)

                                // Expanded content - Calendars
                                if expandedMember?.id == member.id, let memberCals = member.memberCalendars?.allObjects as? [FamilyMemberCalendar] {
                                    let sortedCals = memberCals.sorted { ($0.isAutoLinked && !$1.isAutoLinked) || ($0.isAutoLinked == $1.isAutoLinked && ($0.calendarName ?? "") < ($1.calendarName ?? "")) }

                                    Divider()
                                        .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                    VStack(spacing: 0) {
                                        ForEach(sortedCals, id: \.self) { cal in
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(Color.fromHex(cal.calendarColorHex ?? "#007AFF"))
                                                    .frame(width: 10, height: 10)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(cal.calendarName ?? "Unknown")
                                                        .font(.system(size: 14, weight: .regular))
                                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)
                                                }

                                                Spacer()

                                                if cal.isAutoLinked {
                                                    Image(systemName: "lock.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                                }
                                            }
                                            .padding(.vertical, 12)
                                            .opacity(cal.isAutoLinked ? 0.6 : 1.0)

                                            if cal.id != sortedCals.last?.id {
                                                Divider()
                                                    .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)
                                            }
                                        }
                                    }

                                    Divider()
                                        .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                    // Action buttons in expanded section
                                    VStack(spacing: 0) {
                                        Button(action: { selectedMember = member }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "pencil.circle.fill")
                                                    .font(.system(size: 16))

                                                Text("Select Calendars")
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.plain)

                                        Divider()
                                            .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                        Button(action: { editingMember = member }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "square.and.pencil")
                                                    .font(.system(size: 16))

                                                Text("Edit Member")
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor : .blue)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.plain)

                                        Divider()
                                            .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)

                                        Button(action: { deleteMember(member) }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "trash.fill")
                                                    .font(.system(size: 16))

                                                Text("Delete Member")
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                            .foregroundColor(.red)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .allowsHitTesting(true)
                        .padding(.horizontal, 16)
                    }
                }
            }

            Button(action: { showingAddMember = true }) {
                Text("Add Family Member")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentFillStyle() : AnyShapeStyle(Color(red: 0.33, green: 0.33, blue: 0.33)))
                    .cornerRadius(16)
                    .shadow(color: themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    FamilySettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
