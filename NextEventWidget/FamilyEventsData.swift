//
//  FamilyEventsData.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import WidgetKit

/// Event item for family events list
struct EventItem: Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let memberName: String
    let memberColorHex: String
    let location: String?
}

/// Timeline entry for family events widget
struct FamilyEventsEntry: TimelineEntry {
    let date: Date
    let events: [EventItem]
    let errorMessage: String?
    let maxEvents: Int

    /// Initialize with event list
    init(date: Date = Date(), events: [EventItem], maxEvents: Int = 10) {
        self.date = date
        self.events = events
        self.maxEvents = maxEvents
        self.errorMessage = nil
    }

    /// Initialize with error
    init(date: Date = Date(), errorMessage: String) {
        self.date = date
        self.events = []
        self.maxEvents = 10
        self.errorMessage = errorMessage
    }

    /// Initialize as placeholder
    init(date: Date = Date()) {
        self.date = date
        self.events = []
        self.maxEvents = 10
        self.errorMessage = nil
    }
}
