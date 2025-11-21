import SwiftUI
import CoreData

struct DailyEventsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    var events: [DayEventItem]
    var selectedDate: Date
    var selectedDateString: String
    var familyMembers: [FamilyMember]
    var memberColors: [NSManagedObjectID: UIColor]

    @State private var tappedEvent: DayEventItem?
    @State private var selectedMemberIDs: [NSManagedObjectID] = []
    @State private var currentTime = Date()
    @State private var scrollPositioned = false
    @State private var timer: Timer?

    private let hourHeight: CGFloat = 60
    private let allDayTitleLineHeight: CGFloat = UIFont.systemFont(ofSize: 13, weight: .semibold).lineHeight
    private let allDayRowHeight: CGFloat = UIFont.systemFont(ofSize: 13, weight: .semibold).lineHeight + 4
    private let calendar = Calendar.current
    private var theme: AppTheme { themeManager.selectedTheme }

    var body: some View {
        let filteredEvents = events.filter { event in
            if selectedMemberIDs.isEmpty {
                return true // Show all if no filter is selected
            }
            return !Set(selectedMemberIDs).isDisjoint(with: Set(event.memberIDs))
        }
        let timedEvents = filteredEvents.filter { !$0.isAllDay }
        let allDayEvents = filteredEvents.filter { $0.isAllDay }

        return VStack(alignment: .leading, spacing: 0) {
            Text(selectedDateString)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(theme.cardBackground)

            memberFilterView
                .padding(.bottom, 8)

            if !allDayEvents.isEmpty {
                allDayEventsSection(for: allDayEvents)
            }

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            timelineView
                            eventsView(for: timedEvents)

                            // Current time line
                            if calendar.isDate(selectedDate, inSameDayAs: currentTime) {
                                VStack(spacing: 0) {
                                    Spacer()
                                        .frame(height: yOffset(for: currentTime))

                                    HStack(spacing: 0) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)

                                        Rectangle()
                                            .fill(Color.red)
                                            .frame(height: 0.5)
                                    }
                                    .id("currentTime")

                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if calendar.isDate(selectedDate, inSameDayAs: currentTime) {
                            withAnimation {
                                scrollProxy.scrollTo("currentTime", anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .background(theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
        .onAppear {
            selectedMemberIDs = familyMembers.map { $0.objectID }
            startTimeUpdates()
        }
        .onDisappear {
            stopTimeUpdates()
        }
    }

    private var memberFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(familyMembers) { member in
                    Button(action: {
                        withAnimation {
                            if let index = selectedMemberIDs.firstIndex(of: member.objectID) {
                                selectedMemberIDs.remove(at: index)
                            } else {
                                selectedMemberIDs.append(member.objectID)
                            }
                        }
                    }) {
                        Text(member.name ?? "")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedMemberIDs.contains(member.objectID) ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selectedMemberIDs.contains(member.objectID) ? Color(memberColors[member.objectID] ?? .gray) : Color.clear)
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var timelineView: some View {
        VStack(spacing: 0) {
            ForEach(0..<24) { hour in
                HStack(spacing: 8) {
                    Text(formatHour(hour))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.mutedTagColor)
                        .frame(width: 40, alignment: .trailing)

                    VStack {
                        Divider()
                    }
                }
                .frame(height: hourHeight)
            }
        }
    }

    private func eventsView(for events: [DayEventItem]) -> some View {
        GeometryReader { geometry in
            let eventLayouts = calculateEventLayouts(for: events, availableWidth: geometry.size.width)

            ZStack(alignment: .topLeading) {
                ForEach(eventLayouts) { layout in
                    eventCell(for: layout.event, isTapped: tappedEvent == layout.event)
                        .frame(width: layout.width, height: layout.height)
                        .offset(x: layout.x, y: layout.y)
                        .onTapGesture {
                            withAnimation {
                                if tappedEvent == layout.event {
                                    tappedEvent = nil
                                } else {
                                    tappedEvent = layout.event
                                }
                            }
                        }
                }
            }
            .padding(.leading, 50)
        }
    }

    private func allDayEventsSection(for events: [DayEventItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("All-Day")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(events) { event in
                allDayEventCell(for: event)
            }
        }
        .padding(.bottom, 8)
    }

    private func allDayEventCell(for event: DayEventItem) -> some View {
        let isPast = Date() > event.endDate

        return HStack(alignment: .center, spacing: 8) {
            Capsule()
                .fill(Color(event.color))
                .frame(width: 4, height: allDayTitleLineHeight)
                .opacity(isPast ? 0.6 : 1.0)

            VStack(alignment: .leading) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .opacity(isPast ? 0.7 : 1.0)
                Text(event.memberNames.joined(separator: ", "))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(theme.mutedTagColor)
                    .opacity(isPast ? 0.7 : 1.0)
            }

            Spacer()
        }
        .frame(height: allDayRowHeight)
        .padding(.horizontal, 12)
        .background(Color(event.color).opacity(isPast ? 0.10 : 0.15))
        .cornerRadius(6)
        .padding(.horizontal, 8)
    }

    private func eventCell(for event: DayEventItem, isTapped: Bool) -> some View {
        let isPast = Date() > event.endDate

        return VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .opacity(isPast ? 0.7 : 1.0)

            Text(event.timeRange ?? "")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(isPast ? 0.6 : 0.8))

            Text(event.memberNames.joined(separator: ", "))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(isPast ? 0.6 : 0.8))
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(event.color).opacity(isPast ? (isTapped ? 0.5 : 0.35) : (isTapped ? 1.0 : 0.6)))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(event.color), lineWidth: 1)
                .opacity(isPast ? 0.6 : 1.0)
        )
    }

    private func formatHour(_ hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }

    private func calculateEventLayouts(for events: [DayEventItem], availableWidth: CGFloat) -> [EventLayout] {
        var layouts: [EventLayout] = []
        let sortedEvents = events.sorted { $0.startDate < $1.startDate }
        
        var columns: [[DayEventItem]] = []
        
        for event in sortedEvents {
            var placed = false
            for (columnIndex, column) in columns.enumerated() {
                if let lastEvent = column.last, event.startDate >= lastEvent.endDate {
                    columns[columnIndex].append(event)
                    placed = true
                    break
                }
            }
            if !placed {
                columns.append([event])
            }
        }
        
        let totalColumns = columns.count
        let columnWidth = (availableWidth - 50 - CGFloat(totalColumns > 1 ? (totalColumns - 1) * 4 : 0)) / CGFloat(totalColumns)

        for (columnIndex, column) in columns.enumerated() {
            for event in column {
                let yPosition = yOffset(for: event.startDate)
                let height = max(20, yOffset(for: event.endDate) - yPosition)
                let xPosition = CGFloat(columnIndex) * (columnWidth + 4)
                
                layouts.append(EventLayout(event: event, x: xPosition, y: yPosition, width: columnWidth, height: height))
            }
        }
        
        return layouts
    }

    private func yOffset(for date: Date) -> CGFloat {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return CGFloat(hour) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
    }

    private func startTimeUpdates() {
        currentTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func stopTimeUpdates() {
        timer?.invalidate()
        timer = nil
    }
}

struct EventLayout: Identifiable {
    let id = UUID()
    let event: DayEventItem
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

extension DayEventItem: Equatable {
    static func == (lhs: DayEventItem, rhs: DayEventItem) -> Bool {
        lhs.id == rhs.id
    }
}
