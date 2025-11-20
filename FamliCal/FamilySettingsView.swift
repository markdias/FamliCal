//
//  FamilySettingsView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData

struct FamilySettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @FetchRequest(
        entity: FamilyMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)]
    )
    private var familyMembers: FetchedResults<FamilyMember>

    @State private var showingAddMember = false
    @State private var editingMember: FamilyMember? = nil
    @State private var spotlightMember: FamilyMember? = nil

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Family Members Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Family Members")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                .padding(.horizontal, 16)

                            if familyMembers.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "person.2.circle")
                                        .font(.system(size: 48))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)

                                    Text("No family members yet")
                                        .font(.system(size: 15, weight: .regular, design: .default))
                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                                .glassyCard(padding: 0)
                                .padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(familyMembers.filter { ($0.memberCalendars?.count ?? 0) > 0 }, id: \.self) { member in
                                        FamilyMemberRow(
                                            member: member,
                                            onEdit: { editingMember = member },
                                            onSpotlight: { spotlightMember = member }
                                        )

                                        if member.id != familyMembers.last?.id {
                                            Divider()
                                                .padding(.horizontal, 16)
                                                .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)
                                        }
                                    }
                                }
                                .glassyCard(padding: 0)
                                .padding(.horizontal, 16)
                            }
                        }

                        // Add button
                        Button(action: { showingAddMember = true }) {
                            Text("Add Family Member")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentFillStyle() : AnyShapeStyle(Color(red: 0.33, green: 0.33, blue: 0.33)))
                                .cornerRadius(12)
                                .shadow(color: themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.accentColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)

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
    }

    private func deleteMembers(at offsets: IndexSet) {
        for index in offsets {
            let member = familyMembers[index]
            viewContext.delete(member)
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Error deleting member: \(nsError), \(nsError.userInfo)")
        }
    }
}

struct FamilyMemberRow: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let member: FamilyMember
    let onEdit: () -> Void
    let onSpotlight: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Colored dot from first linked calendar
            if let firstCalendar = (member.memberCalendars?.allObjects as? [FamilyMemberCalendar])?.first {
                Circle()
                    .fill(Color.fromHex(firstCalendar.calendarColorHex ?? "#555555"))
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 12, height: 12)
            }

            // Member info
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name ?? "Unknown")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)

                if let memberCals = member.memberCalendars, memberCals.count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)

                        Text("\(memberCals.count) calendar\(memberCals.count != 1 ? "s" : "")")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)

                        Text("No calendars linked")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                    }
                }
            }

            Spacer()

            // Spotlight button
            Button(action: onSpotlight) {
                Image(systemName: "spotlight")
                    .font(.system(size: 16))
                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : Color(red: 0.33, green: 0.33, blue: 0.33))
            }
            .padding(.horizontal, 4)

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

#Preview {
    FamilySettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
