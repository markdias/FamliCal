//
//  NextEventWidget.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import WidgetKit
import SwiftUI

@main
struct NextEventWidget: Widget {
    let kind: String = "NextEventWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextEventProvider()) { entry in
            NextEventWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Family Event")
        .description("Shows the next upcoming event for your family members")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    NextEventWidget()
} timeline: {
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

    NextEventEntry(date: Date(), event: mockEvent, familyMember: mockMember)
}
