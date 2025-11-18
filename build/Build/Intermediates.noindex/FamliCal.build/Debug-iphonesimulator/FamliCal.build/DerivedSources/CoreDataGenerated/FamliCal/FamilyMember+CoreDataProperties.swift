//
//  FamilyMember+CoreDataProperties.swift
//  
//
//  Created by Mark Dias on 18/11/2025.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias FamilyMemberCoreDataPropertiesSet = NSSet

extension FamilyMember {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FamilyMember> {
        return NSFetchRequest<FamilyMember>(entityName: "FamilyMember")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var linkedCalendarID: String?
    @NSManaged public var colorHex: String?
    @NSManaged public var avatarInitials: String?
    @NSManaged public var memberCalendars: NSSet?
    @NSManaged public var sharedCalendars: NSSet?
    @NSManaged public var familyEvents: NSSet?

}

// MARK: Generated accessors for memberCalendars
extension FamilyMember {

    @objc(addMemberCalendarsObject:)
    @NSManaged public func addToMemberCalendars(_ value: FamilyMemberCalendar)

    @objc(removeMemberCalendarsObject:)
    @NSManaged public func removeFromMemberCalendars(_ value: FamilyMemberCalendar)

    @objc(addMemberCalendars:)
    @NSManaged public func addToMemberCalendars(_ values: NSSet)

    @objc(removeMemberCalendars:)
    @NSManaged public func removeFromMemberCalendars(_ values: NSSet)

}

// MARK: Generated accessors for sharedCalendars
extension FamilyMember {

    @objc(addSharedCalendarsObject:)
    @NSManaged public func addToSharedCalendars(_ value: SharedCalendar)

    @objc(removeSharedCalendarsObject:)
    @NSManaged public func removeFromSharedCalendars(_ value: SharedCalendar)

    @objc(addSharedCalendars:)
    @NSManaged public func addToSharedCalendars(_ values: NSSet)

    @objc(removeSharedCalendars:)
    @NSManaged public func removeFromSharedCalendars(_ values: NSSet)

}

// MARK: Generated accessors for familyEvents
extension FamilyMember {

    @objc(addFamilyEventsObject:)
    @NSManaged public func addToFamilyEvents(_ value: FamilyEvent)

    @objc(removeFamilyEventsObject:)
    @NSManaged public func removeFromFamilyEvents(_ value: FamilyEvent)

    @objc(addFamilyEvents:)
    @NSManaged public func addToFamilyEvents(_ values: NSSet)

    @objc(removeFamilyEvents:)
    @NSManaged public func removeFromFamilyEvents(_ values: NSSet)

}

extension FamilyMember : Identifiable {

}
