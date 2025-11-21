//
//  NextEventWidgetView.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import SwiftUI
import WidgetKit

/// Condensed widget UI for displaying next upcoming event
struct NextEventWidgetView: View {
    let entry: NextEventProvider.Entry

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.secondarySystemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let event = entry.event, let member = entry.familyMember {
                // Content with event
                VStack(alignment: .leading, spacing: 8) {
                    // Header: Member avatar and name
                    HStack(spacing: 8) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color(UIColor(hex: member.colorHex)))

                            Text(member.initials)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 32, height: 32)

                        // Member name
                        Text(member.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        // Status badge
                        StatusBadge(event: event)
                            .font(.system(size: 10, weight: .medium))
                    }

                    Divider()
                        .opacity(0.5)

                    // Event title
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))

                        Text(event.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12))

                        Spacer()
                    }
                    .foregroundColor(.secondary)

                    // Location (if available)
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11))

                            Text(location)
                                .font(.system(size: 11))
                                .lineLimit(1)

                            Spacer()
                        }
                        .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
            } else if let error = entry.errorMessage {
                // Error state
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)

                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .lineLimit(3)

                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                // Loading/placeholder state
                VStack(alignment: .center, spacing: 8) {
                    ProgressView()
                        .tint(.blue)

                    Text("Loading events...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .widgetURL(deepLinkURL)
    }

    /// Generate deep link to event (to be handled by main app)
    private var deepLinkURL: URL? {
        guard let event = entry.event, let member = entry.familyMember else { return nil }
        var components = URLComponents(string: "famli://event")
        components?.queryItems = [
            URLQueryItem(name: "title", value: event.title),
            URLQueryItem(name: "date", value: ISO8601DateFormatter().string(from: event.startDate)),
            URLQueryItem(name: "memberId", value: member.id.uuidString)
        ]
        return components?.url
    }
}

/// Status badge showing event state
struct StatusBadge: View {
    let event: WidgetEventData

    var statusText: String {
        let now = Date()
        if event.startDate <= now && now < event.endDate {
            return "In Progress"
        } else if event.startDate.timeIntervalSince(now) <= 3600 {
            return "Soon"
        } else {
            return "Upcoming"
        }
    }

    var statusColor: Color {
        let now = Date()
        if event.startDate <= now && now < event.endDate {
            return .red
        } else if event.startDate.timeIntervalSince(now) <= 3600 {
            return .orange
        } else {
            return .blue
        }
    }

    var body: some View {
        Text(statusText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }
}

/// Extension to generate initials from member name
extension FamilyMemberData {
    var initials: String {
        let parts = name.split(separator: " ").map(String.init)
        let result = parts.prefix(2).map { $0.first.map(String.init) ?? "" }.joined()
        return result.isEmpty ? "?" : result.uppercased()
    }
}

#Preview("Next Event") {
    let mockEvent = WidgetEventData(
        title: "Team Meeting",
        startDate: Date(timeIntervalSinceNow: 1800),
        endDate: Date(timeIntervalSinceNow: 5400),
        location: "Conference Room A",
        colorHex: "#007AFF"
    )

    let mockMember = FamilyMemberData(
        id: UUID(),
        name: "John Doe",
        colorHex: "#007AFF"
    )

    let entry = NextEventEntry(date: Date(), event: mockEvent, familyMember: mockMember)

    NextEventWidgetView(entry: entry)
        .preferredColorScheme(.light)
}

#Preview("Loading") {
    let entry = NextEventEntry(date: Date())
    NextEventWidgetView(entry: entry)
}

#Preview("Error") {
    let entry = NextEventEntry(date: Date(), errorMessage: "No upcoming events")
    NextEventWidgetView(entry: entry)
}
