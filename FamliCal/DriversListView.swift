//
//  DriversListView.swift
//  FamliCal
//
//  Created by Codex on 20/11/2025.
//

import SwiftUI
import CoreData

struct DriversListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @FetchRequest(entity: Driver.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Driver.name, ascending: true)]) private var drivers: FetchedResults<Driver>

    @State private var showingAddDriver = false

    var body: some View {
        NavigationView {
            GlassyBackground {
                ScrollView {
                    VStack(spacing: 24) {
                        if drivers.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                Text("No Drivers")
                                    .font(.headline)
                                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .gray)
                                Text("Add drivers to manage who can drive to events")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                            .glassyCard(padding: 0)
                            .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(drivers, id: \.self) { driver in
                                    VStack(spacing: 0) {
                                        NavigationLink(destination: EditDriverView(driver: driver)) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(driver.name ?? "Unknown")
                                                        .font(.headline)
                                                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textPrimary : .primary)
                                                    if let phone = driver.phone, !phone.isEmpty {
                                                        Text(phone)
                                                            .font(.subheadline)
                                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                                    }
                                                    if let email = driver.email, !email.isEmpty {
                                                        Text(email)
                                                            .font(.subheadline)
                                                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                                    }
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? themeManager.selectedTheme.textSecondary : .gray)
                                            }
                                            .padding()
                                        }
                                        .buttonStyle(.plain)

                                        if driver.id != drivers.last?.id {
                                            Divider()
                                                .padding(.horizontal, 16)
                                                .opacity(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? 0.3 : 1.0)
                                        }
                                    }
                                }
                                .onDelete(perform: deleteDrivers)
                            }
                            .glassyCard(padding: 0)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Drivers")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                        }
                        .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? .white : .blue)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddDriver = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(themeManager.selectedTheme.id == AppTheme.launchFlow.id ? .white : .blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddDriver) {
                AddDriverView()
            }
        }
    }

    private func deleteDrivers(offsets: IndexSet) {
        withAnimation {
            offsets.map { drivers[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
                print("✅ Driver deleted successfully")
            } catch {
                print("❌ Failed to delete driver: \(error.localizedDescription)")
                let nsError = error as NSError
                print("   Error: \(nsError.domain) - \(nsError.code)")
            }
        }
    }
}

#Preview {
    DriversListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
