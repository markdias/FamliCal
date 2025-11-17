//
//  MainTabView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData

struct MainTabView: View {
    @State private var showingSettings = false
    @State private var showingAddEvent = false
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            TabView {
                FamilyView()
                    .tabItem {
                        Label("Events", systemImage: "calendar.badge.checkmark")
                    }

                CalendarView()
                    .tabItem {
                        Label("Calendar", systemImage: "calendar")
                    }
            }

            // Floating action buttons
            VStack {
                Spacer()
                HStack {
                    // Settings button in bottom left
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .frame(width: 56, height: 56)
                            .background(Color(.systemBackground))
                            .cornerRadius(28)
                            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
                    }

                    Spacer()

                    // Add event button in bottom right
                    Button(action: { showingAddEvent = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.blue)
                            .cornerRadius(28)
                            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView()
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
