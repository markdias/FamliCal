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
            ZStack {
                Color(hex: "F2F2F7").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if drivers.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("No Drivers")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Add drivers to manage who can drive to events")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
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
                                                        .foregroundColor(.primary)
                                                    if let phone = driver.phone, !phone.isEmpty {
                                                        Text(phone)
                                                            .font(.subheadline)
                                                            .foregroundColor(.gray)
                                                    }
                                                    if let email = driver.email, !email.isEmpty {
                                                        Text(email)
                                                            .font(.subheadline)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.gray.opacity(0.5))
                                            }
                                            .padding()
                                        }
                                        .buttonStyle(.plain)

                                        if driver.id != drivers.last?.id {
                                            Divider()
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Drivers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                        }
                        .foregroundColor(.black)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddDriver = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddDriver) {
                AddDriverView()
            }
        }
    }

}

#Preview {
    DriversListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
