//
//  NextEventConfigurationIntent.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import AppIntents

@available(iOS 17.0, *)
struct NextEventConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Next Event Options"

    @Parameter(title: "Mode", default: .familyNext)
    var mode: NextEventDisplayMode?

    @Parameter(title: "Member name", default: "Auto")
    var memberName: String?

    init() {}
}

/// Modes for the next event widget
enum NextEventDisplayMode: String, AppEnum, CaseIterable {
    case familyNext
    case memberNext

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display Mode")

    static var caseDisplayRepresentations: [NextEventDisplayMode: DisplayRepresentation] {
        [
            .familyNext: "Next Family Event",
            .memberNext: "Specific Member"
        ]
    }
}
