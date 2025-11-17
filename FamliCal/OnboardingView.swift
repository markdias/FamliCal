//
//  OnboardingView.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI

enum OnboardingStep {
    case intro
    case permission
    case ready
}

struct OnboardingView: View {
    @State private var currentStep: OnboardingStep = .intro
    @State private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            switch currentStep {
            case .intro:
                IntroScreen(onGetStarted: {
                    withAnimation {
                        currentStep = .permission
                    }
                })

            case .permission:
                PermissionScreen(onNext: {
                    withAnimation {
                        currentStep = .ready
                    }
                })

            case .ready:
                ReadyScreen(onStartUsingApp: {
                    completeOnboarding()
                })
            }
        }
        .fullScreenCover(isPresented: $hasCompletedOnboarding) {
            FamilyView()
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView()
}
