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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Family Members Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Family Members")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)

                        if familyMembers.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)

                                Text("No family members yet")
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
                                    }
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }
                    }

                    // Add button
                    Button(action: { showingAddMember = true }) {
                        Text("Add Family Member")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
                .padding(.vertical, 16)
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
    let member: FamilyMember
    let onEdit: () -> Void
    let onSpotlight: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Member info
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name ?? "Unknown")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                if let memberCals = member.memberCalendars, memberCals.count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)

                        Text("\(memberCals.count) calendar\(memberCals.count != 1 ? "s" : "") linked")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)

                        Text("No calendars linked")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            // Spotlight button
            Button(action: onSpotlight) {
                Image(systemName: "spotlight")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 8)

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

#Preview {
    FamilySettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
