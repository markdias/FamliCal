//
//  IntroScreen.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI

struct IntroScreen: View {
    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top spacer
            Spacer()

            // Icon/Header area
            VStack(spacing: 16) {
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Welcome to FamliCal")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .tracking(0.5)

                Text("Keep your family connected, one calendar at a time")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            // Center spacer
            Spacer()

            // Bottom section with button
            VStack(spacing: 16) {
                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    IntroScreen(onGetStarted: {})
}
