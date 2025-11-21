//
//  FamilyEvent+CoreDataProperties.swift
//  
//
//  Created by Mark Dias on 21/11/2025.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias FamilyEventCoreDataPropertiesSet = NSSet

extension FamilyEvent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FamilyEvent> {
        return NSFetchRequest<FamilyEvent>(entityName: "FamilyEvent")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var eventGroupId: UUID?
    @NSManaged public var eventIdentifier: String?
    @NSManaged public var calendarId: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var isSharedCalendarEvent: Bool
    @NSManaged public var attendees: NSSet?
    @NSManaged public var driver: Driver?

}

// MARK: Generated accessors for attendees
extension FamilyEvent {

    @objc(addAttendeesObject:)
    @NSManaged public func addToAttendees(_ value: FamilyMember)

    @objc(removeAttendeesObject:)
    @NSManaged public func removeFromAttendees(_ value: FamilyMember)

    @objc(addAttendees:)
    @NSManaged public func addToAttendees(_ values: NSSet)

    @objc(removeAttendees:)
    @NSManaged public func removeFromAttendees(_ values: NSSet)

}

extension FamilyEvent : Identifiable {

}
