//
//  ReadyScreen.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI

struct ReadyScreen: View {
    var onStartUsingApp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top spacer
            Spacer()

            // Success content
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)

                VStack(spacing: 12) {
                    Text("You're all set!")
                        .font(.system(size: 32, weight: .bold, design: .default))

                    Text("Your family calendar is ready to go. Start sharing events with your loved ones.")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 24)

            // Bottom spacer
            Spacer()

            // Action button
            VStack(spacing: 16) {
                Button(action: onStartUsingApp) {
                    Text("Start Using FamliCal")
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
    ReadyScreen(onStartUsingApp: {})
}
