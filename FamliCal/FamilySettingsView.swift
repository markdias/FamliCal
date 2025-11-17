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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 0) {
                        Text("Family Members")
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                    // Family Members Section
                    VStack(alignment: .leading, spacing: 12) {
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
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(familyMembers.filter { ($0.memberCalendars?.count ?? 0) > 0 }, id: \.self) { member in
                                    FamilyMemberRow(member: member, onEdit: {
                                        editingMember = member
                                    })

                                    if member.id != familyMembers.last?.id {
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

                    // Add button
                    Button(action: { showingAddMember = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))

                            Text("Add Family Member")
                                .font(.system(size: 16, weight: .semibold, design: .default))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
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
        .sheet(isPresented: $showingAddMember) {
            AddFamilyMemberView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $editingMember) { member in
            EditFamilyMemberView(member: member)
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

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.fromHex(member.colorHex ?? "#007AFF"))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(member.avatarInitials ?? "?")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                    )

                // Member info
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name ?? "Unknown")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.primary)

                    if let memberCals = member.memberCalendars, memberCals.count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)

                            Text("\(memberCals.count) calendar\(memberCals.count != 1 ? "s" : "") linked")
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundColor(.gray)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)

                            Text("No calendars linked")
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundColor(.gray)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    FamilySettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
