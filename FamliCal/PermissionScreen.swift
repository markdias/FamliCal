//
//  PermissionScreen.swift
//  FamliCal
//
//  Created by Mark Dias on 17/11/2025.
//

import SwiftUI
import EventKit

struct PermissionScreen: View {
    @State private var calendarPermissionGranted = false
    @State private var isRequestingPermission = false

    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top spacer
            Spacer()

            // Header
            VStack(spacing: 16) {
                Image(systemName: "lock.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                Text("Calendar Access")
                    .font(.system(size: 28, weight: .bold, design: .default))

                Text("To sync your family events, we need access to your calendar")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)

            // Middle spacer
            Spacer()

            // Permission section
            VStack(spacing: 16) {
                Button(action: requestCalendarPermission) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Calendar")
                                .font(.system(size: 16, weight: .semibold, design: .default))
                                .foregroundColor(.primary)

                            Text(calendarPermissionGranted ? "Access granted" : "Tap to allow")
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        if calendarPermissionGranted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .disabled(isRequestingPermission)
            }
            .padding(.horizontal, 24)

            // Bottom spacer - only show Next button if permission granted
            Spacer()

            // Next button (only visible when permission is granted)
            VStack(spacing: 16) {
                if calendarPermissionGranted {
                    Button(action: onNext) {
                        Text("Next")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            checkCalendarPermission()
        }
    }

    private func checkCalendarPermission() {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized:
            calendarPermissionGranted = true
        default:
            calendarPermissionGranted = false
        }
    }

    private func requestCalendarPermission() {
        guard !isRequestingPermission else { return }

        isRequestingPermission = true
        let eventStore = EKEventStore()

        eventStore.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                isRequestingPermission = false
                if granted {
                    calendarPermissionGranted = true
                }
            }
        }
    }
}

#Preview {
    PermissionScreen(onNext: {})
}
