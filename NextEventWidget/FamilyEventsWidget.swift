//
//  FamilyEventsWidget.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import WidgetKit
import SwiftUI

@main
struct FamliCalWidgets: WidgetBundle {
    var body: some Widget {
        if #available(iOS 17.0, *) {
            NextEventWidget()
        }
        FamilyEventsWidget()
    }
}

struct FamilyEventsWidget: Widget {
    let kind: String = "FamilyEventsWidget"

    var body: some WidgetConfiguration {
        if #available(iOS 17.0, *) {
            StaticConfiguration(kind: kind, provider: FamilyEventsProvider()) { entry in
                FamilyEventsWidgetView(entry: entry)
            }
            .configurationDisplayName("Family Events")
            .description("See upcoming events for all family members")
            .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
        } else {
            StaticConfiguration(kind: kind, provider: FamilyEventsProvider()) { entry in
                FamilyEventsWidgetView(entry: entry)
            }
            .configurationDisplayName("Family Events")
            .description("See upcoming events for all family members")
            .supportedFamilies([.systemMedium, .systemLarge])
        }
    }
}
