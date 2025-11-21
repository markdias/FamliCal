//
//  PremiumManager.swift
//  FamliCal
//
//  Created by Codex on 21/11/2025.
//

import Foundation
import Combine

class PremiumManager: ObservableObject {
    @Published var isPremium: Bool {
        didSet {
            UserDefaults.standard.set(isPremium, forKey: "isPremium")
        }
    }

    // MARK: - Premium Feature Limits
    let freeMaxFamilyMembers = 2
    let freeMaxSharedCalendars = 1

    init() {
        self.isPremium = UserDefaults.standard.bool(forKey: "isPremium")
    }

    // MARK: - Feature Availability

    func canAddMoreFamilyMembers(currentCount: Int) -> Bool {
        if isPremium {
            return true
        }
        return currentCount < freeMaxFamilyMembers
    }

    func canAddMoreSharedCalendars(currentCount: Int) -> Bool {
        if isPremium {
            return true
        }
        return currentCount < freeMaxSharedCalendars
    }

    func familyMembersLimitReached(currentCount: Int) -> Bool {
        if isPremium { return false }
        return currentCount >= freeMaxFamilyMembers
    }

    func sharedCalendarsLimitReached(currentCount: Int) -> Bool {
        if isPremium { return false }
        return currentCount >= freeMaxSharedCalendars
    }

    // MARK: - Premium Features (for future use)

    var hasAdvancedNotifications: Bool {
        isPremium
    }

    var hasCustomThemes: Bool {
        isPremium
    }

    var hasSavedAddresses: Bool {
        isPremium
    }

    var hasEventAnalytics: Bool {
        isPremium
    }
}
