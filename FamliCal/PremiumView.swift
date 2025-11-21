//
//  PremiumView.swift
//  FamliCal
//
//  Created by Codex on 21/11/2025.
//

import SwiftUI
import CoreData

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var premiumManager: PremiumManager
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F2F2F7")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .center, spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "6A5AE0"))

                            Text("Premium Membership")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)

                            Text("Unlock unlimited features for your family")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 20)

                        // Testing Toggle (For Development)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Premium Status")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)

                                    Text("Toggle for testing purposes")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Toggle("", isOn: $premiumManager.isPremium)
                                    .tint(Color(hex: "6A5AE0"))
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal, 16)

                        // Current Status Badge
                        HStack {
                            Image(systemName: premiumManager.isPremium ? "checkmark.circle.fill" : "info.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(premiumManager.isPremium ? .green : .orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(premiumManager.isPremium ? "Premium Active" : "Free Plan")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)

                                Text(premiumManager.isPremium ? "You have unlimited access to all features" : "Upgrade to unlock premium features")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.gray)
                            }

                            Spacer()
                        }
                        .padding(16)
                        .background(premiumManager.isPremium ? Color(hex: "E8F5E9") : Color(hex: "FFF3E0"))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)

                        // Feature Comparison Chart
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Feature Comparison")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)

                            // Comparison Table
                            VStack(spacing: 0) {
                                // Header Row
                                HStack {
                                    Text("Feature")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    VStack(spacing: 4) {
                                        Text("Free")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.black)
                                        Text("Plan")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 70, alignment: .center)

                                    VStack(spacing: 4) {
                                        Text("Premium")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: "6A5AE0"))
                                        Text("Plan")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 70, alignment: .center)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color(hex: "F8F8F8"))

                                Divider().padding(.horizontal, 16)

                                // Feature Rows
                                ForEach(featureRows, id: \.feature) { row in
                                    FeatureComparisonRow(
                                        feature: row.feature,
                                        freeValue: row.freeValue,
                                        premiumValue: row.premiumValue,
                                        freeHasFeature: row.freeHasFeature
                                    )
                                    Divider().padding(.leading, 16)
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal, 16)
                        }

                        // Why Premium Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Why Upgrade?")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)

                            VStack(spacing: 12) {
                                BenefitRow(
                                    icon: "person.3.fill",
                                    title: "Unlimited Family Members",
                                    description: "Add as many family members as you need"
                                )

                                BenefitRow(
                                    icon: "calendar.circle.fill",
                                    title: "Unlimited Shared Calendars",
                                    description: "Share all family calendars without limits"
                                )

                                BenefitRow(
                                    icon: "bell.badge.fill",
                                    title: "Advanced Notifications",
                                    description: "Custom notification schedules and preferences"
                                )

                                BenefitRow(
                                    icon: "palette.fill",
                                    title: "Custom Themes",
                                    description: "Personalize your calendar experience"
                                )

                                BenefitRow(
                                    icon: "location.fill",
                                    title: "Saved Addresses Library",
                                    description: "Save and reuse frequent event locations"
                                )

                                BenefitRow(
                                    icon: "chart.bar.fill",
                                    title: "Event Analytics",
                                    description: "Track and analyze family schedules"
                                )
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }

    private var featureRows: [FeatureRow] {
        [
            FeatureRow(
                feature: "Family Members",
                freeValue: "Up to 2",
                premiumValue: "Unlimited",
                freeHasFeature: true
            ),
            FeatureRow(
                feature: "Shared Calendars",
                freeValue: "Up to 1",
                premiumValue: "Unlimited",
                freeHasFeature: true
            ),
            FeatureRow(
                feature: "Event Creation",
                freeValue: "Basic",
                premiumValue: "Advanced",
                freeHasFeature: true
            ),
            FeatureRow(
                feature: "Notifications",
                freeValue: "Standard",
                premiumValue: "Advanced",
                freeHasFeature: true
            ),
            FeatureRow(
                feature: "Custom Themes",
                freeValue: "Standard",
                premiumValue: "Full Access",
                freeHasFeature: false
            ),
            FeatureRow(
                feature: "Saved Addresses",
                freeValue: "Unavailable",
                premiumValue: "Unlimited",
                freeHasFeature: false
            ),
            FeatureRow(
                feature: "Event Analytics",
                freeValue: "Unavailable",
                premiumValue: "Full Analytics",
                freeHasFeature: false
            ),
        ]
    }
}

struct FeatureRow {
    let feature: String
    let freeValue: String
    let premiumValue: String
    let freeHasFeature: Bool
}

struct FeatureComparisonRow: View {
    let feature: String
    let freeValue: String
    let premiumValue: String
    let freeHasFeature: Bool

    var body: some View {
        HStack {
            Text(feature)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                if freeHasFeature {
                    Text(freeValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                }
            }
            .frame(width: 70, alignment: .center)

            VStack(spacing: 0) {
                Text(premiumValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "6A5AE0"))
            }
            .frame(width: 70, alignment: .center)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "6A5AE0"))
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)

                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(hex: "F8F8F8"))
        .cornerRadius(8)
    }
}

#Preview {
    PremiumView()
        .environmentObject(PremiumManager())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
