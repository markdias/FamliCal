//
//  FamliCalApp.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import CoreData

@main
struct FamliCalApp: App {
    let persistenceController = PersistenceController.shared
    @State private var hasCompletedOnboarding: Bool?
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var premiumManager = PremiumManager()

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "eventsPastDays": 90,
            "eventsFutureDays": 180
        ])

        if defaults.integer(forKey: "eventsPastDays") == 0 {
            defaults.set(90, forKey: "eventsPastDays")
        }

        if defaults.integer(forKey: "eventsFutureDays") == 0 {
            defaults.set(180, forKey: "eventsFutureDays")
        }

        // Load onboarding state on first access
        _hasCompletedOnboarding = State(initialValue: nil)

        // Move diagnostics off main thread to prevent blocking UI
        DispatchQueue.global(qos: .utility).async {
            PersistenceController.printStoreDiagnostics()
            print("🚀 FamliCal app launched")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let completed = hasCompletedOnboarding {
                    if completed {
                        MainTabView()
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                            .environmentObject(themeManager)
                            .environmentObject(premiumManager)
                    } else {
                        OnboardingView()
                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
                            .environmentObject(themeManager)
                            .environmentObject(premiumManager)
                    }
                } else {
                    OnboardingView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(themeManager)
                        .environmentObject(premiumManager)
                        .onAppear {
                            hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                        }
                }
            }
            .preferredColorScheme(themeManager.selectedTheme.prefersDarkInterface ? .dark : .light)
        }
    }
}
