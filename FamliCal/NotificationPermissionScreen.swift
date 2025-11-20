//
//  NotificationPermissionScreen.swift
//  FamliCal
//
//  Created by Mark Dias on 20/11/2025.
//

import SwiftUI

struct NotificationPermissionScreen: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var isRequesting = false
    @State private var hasRequested = false
    @State private var permissionGranted = false

    var onNext: () -> Void

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                    .padding(.bottom, 16)

                // Title and Description
                VStack(spacing: 12) {
                    Text("Stay Updated")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Get notified about upcoming family events and important dates")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding(.horizontal, 16)

                Spacer()

                // Permission Status
                if hasRequested {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: permissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(permissionGranted ? .green : .orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(permissionGranted ? "Notifications Enabled" : "Notifications Disabled")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text(permissionGranted
                                    ? "You'll receive event notifications"
                                    : "You can enable notifications in Settings"
                                )
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                }

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button(action: requestPermission) {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(hasRequested ? "Request Again" : "Enable Notifications")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isRequesting)

                    Button(action: onNext) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            checkInitialPermission()
        }
    }

    private func requestPermission() {
        isRequesting = true
        Task {
            let granted = await notificationManager.requestNotificationPermission()
            await MainActor.run {
                permissionGranted = granted
                hasRequested = true
                isRequesting = false
            }
        }
    }

    private func checkInitialPermission() {
        Task {
            let granted = await notificationManager.checkNotificationPermission()
            await MainActor.run {
                if granted {
                    permissionGranted = true
                    hasRequested = true
                }
            }
        }
    }
}

#Preview {
    NotificationPermissionScreen(onNext: {})
}
