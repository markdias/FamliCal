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
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            } else {
                OnboardingView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
}
