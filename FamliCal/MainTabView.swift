//
//  MainTabView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData

struct MainTabView: View {
    private enum ActiveView: String {
        case events
        case calendar

        var title: String {
            switch self {
            case .events:
                return "Events"
            case .calendar:
                return "Calendar"
            }
        }
    }

    @State private var activeView: ActiveView = .events
    @State private var showingSettings = false
    @State private var showingAddEvent = false
    @State private var showingSearch = false
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                switch activeView {
                case .events:
                    FamilyView()
                case .calendar:
                    CalendarView()
                }
            }

            // Floating action buttons
            VStack {
                Spacer()
                HStack(alignment: .center) {
                    HStack(spacing: 12) {
                        settingsButton
                        searchButton
                    }

                    Spacer()

                    viewToggleButton

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
        .sheet(isPresented: $showingSearch) {
            EventSearchView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView()
                .environment(\.managedObjectContext, viewContext)
        }
    }

    private var settingsButton: some View {
        Button(action: { showingSettings = true }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 56, height: 56)
                .background(Color(.systemBackground))
                .cornerRadius(28)
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        }
        .accessibilityLabel("Open settings")
    }

    private var searchButton: some View {
        Button(action: { showingSearch = true }) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 48, height: 48)
                .background(Color(.systemBackground))
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        }
        .accessibilityLabel("Search events")
    }

    private var viewToggleButton: some View {
        let (iconName, label, hint): (String, String, String) = {
            switch activeView {
            case .events:
                return ("calendar", "Open calendar view", "Switch to calendar grid")
            case .calendar:
                return ("list.bullet.rectangle", "Return to event list", "Switch to events list")
            }
        }()

        return Button(action: toggleActiveView) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 56, height: 56)
                .background(Color(.systemBackground))
                .cornerRadius(28)
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint)
    }

    private func switchToView(_ target: ActiveView) {
        guard activeView != target else { return }
        withAnimation(.spring()) {
            activeView = target
        }
    }

    private func toggleActiveView() {
        let next: ActiveView = {
            switch activeView {
            case .events:
                return .calendar
            case .calendar:
                return .events
            }
        }()
        switchToView(next)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
