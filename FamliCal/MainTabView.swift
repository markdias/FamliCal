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
    @EnvironmentObject private var themeManager: ThemeManager

    private var theme: AppTheme {
        themeManager.selectedTheme
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                switch activeView {
                case .events:
                    FamilyView(
                        onSearchRequested: { showingSearch = true },
                        onAddEventRequested: { showingAddEvent = true },
                        onChangeViewRequested: { switchToView(.calendar) }
                    )
                case .calendar:
                    CalendarView()
                }
            }

            // Floating action buttons
            if activeView == .calendar {
                VStack {
                    Spacer()
                    HStack(alignment: .center) {
                        compactControlStack

                        Spacer()

                        // Add event button in bottom right
                        primaryActionButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
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

    private var compactControlStack: some View {
        HStack(spacing: 12) {
            SettingsControlButton(imageName: "gearshape.fill", action: {
                showingSettings = true
            }, theme: theme)
            .accessibilityLabel("Open settings")

            SettingsControlButton(imageName: "magnifyingglass", action: {
                showingSearch = true
            }, theme: theme)
            .accessibilityLabel("Search events")

            SettingsControlButton(imageName: activeView == .events ? "calendar" : "list.bullet.rectangle", action: {
                toggleActiveView()
            }, theme: theme)
            .accessibilityLabel(activeView == .events ? "Open calendar view" : "Return to event list")
            .accessibilityHint(activeView == .events ? "Switch to calendar grid" : "Switch to events list")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.floatingControlsBackground)
        .overlay(
            Capsule()
                .stroke(theme.floatingControlsBorder, lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
    }

    private var primaryActionButton: some View {
        Button(action: { showingAddEvent = true }) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(theme.accentFillStyle())
                )
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
        }
        .accessibilityLabel("Add event")
    }

    private struct SettingsControlButton: View {
        let imageName: String
        let action: () -> Void
        let theme: AppTheme

        var body: some View {
            Button(action: action) {
                Image(systemName: imageName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.floatingControlForeground)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(theme.chromeOverlay)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
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
        .environmentObject(ThemeManager())
}
