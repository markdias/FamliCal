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
        sortDescriptors: [
            NSSortDescriptor(keyPath: \FamilyMember.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \FamilyMember.name, ascending: true)
        ]
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
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Family Members Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Family Members")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                if !familyMembers.isEmpty {
                                    EditButton()
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 16)

                            if familyMembers.isEmpty {
                                emptyStateView
                            } else {
                                List {
                                    ForEach(familyMembers) { member in
                                        memberRow(for: member)
                                            .listRowInsets(EdgeInsets())
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(Color.clear)
                                    }
                                    .onMove(perform: moveMembers)
                                }
                                .listStyle(.plain)
                                .frame(height: CGFloat(familyMembers.count * 70 + (expandedMember != nil ? 150 : 0))) // Dynamic height approximation
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal, 16)
                                .scrollDisabled(true) // Disable scrolling within the list, let the main ScrollView handle it
                            }
                        }

                        Spacer()
                        
                        Button(action: { showingAddMember = true }) {
                            Text("Add Family Member")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(12)
                                .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Family")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Back")
                        }
                        .foregroundColor(.black)
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
    
    private func moveMembers(from source: IndexSet, to destination: Int) {
        var revisedItems = familyMembers.map { $0 }
        revisedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in revisedItems.enumerated() {
            item.sortOrder = Int16(index)
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Error saving order: \(nsError), \(nsError.userInfo)")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No family members yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private func memberRow(for member: FamilyMember) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation {
                    if expandedMember?.id == member.id {
                        expandedMember = nil
                    } else {
                        expandedMember = member
                    }
                }
            }) {
                HStack(spacing: 16) {
                    if let firstCalendar = (member.memberCalendars?.allObjects as? [FamilyMemberCalendar])?.first {
                        Circle()
                            .fill(Color.fromHex(firstCalendar.calendarColorHex ?? "#007AFF"))
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 32, height: 32)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name ?? "Unknown")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)

                        Text("\((member.memberCalendars?.count) ?? 0) calendar\((member.memberCalendars?.count) ?? 0 != 1 ? "s" : "")")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: expandedMember?.id == member.id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Expanded content
            if expandedMember?.id == member.id {
                expandedContent(for: member)
            }
        }
    }
    
    private func expandedContent(for member: FamilyMember) -> some View {
        VStack(spacing: 0) {
            Divider()
            
            if let memberCals = member.memberCalendars?.allObjects as? [FamilyMemberCalendar] {
                let sortedCals = memberCals.sorted { ($0.isAutoLinked && !$1.isAutoLinked) || ($0.isAutoLinked == $1.isAutoLinked && ($0.calendarName ?? "") < ($1.calendarName ?? "")) }
                
                ForEach(sortedCals, id: \.self) { cal in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.fromHex(cal.calendarColorHex ?? "#007AFF"))
                            .frame(width: 8, height: 8)

                        Text(cal.calendarName ?? "Unknown")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)

                        Spacer()

                        if cal.isAutoLinked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "F9F9F9"))
                }
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 0) {
                Button(action: { selectedMember = member }) {
                    Label("Calendars", systemImage: "pencil.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                
                Divider().frame(height: 24)
                
                Button(action: { editingMember = member }) {
                    Label("Edit", systemImage: "square.and.pencil")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                
                Divider().frame(height: 24)
                
                Button(action: { deleteMember(member) }) {
                    Label("Delete", systemImage: "trash.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .background(Color(hex: "F9F9F9"))
        }
    }
}

#Preview {
    FamilySettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
