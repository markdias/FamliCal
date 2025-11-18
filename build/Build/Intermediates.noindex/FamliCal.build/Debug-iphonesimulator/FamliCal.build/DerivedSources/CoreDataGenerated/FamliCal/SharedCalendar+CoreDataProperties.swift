//
//  SharedCalendar+CoreDataProperties.swift
//  
//
//  Created by Mark Dias on 18/11/2025.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias SharedCalendarCoreDataPropertiesSet = NSSet

extension SharedCalendar {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SharedCalendar> {
        return NSFetchRequest<SharedCalendar>(entityName: "SharedCalendar")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var calendarID: String?
    @NSManaged public var calendarName: String?
    @NSManaged public var calendarColorHex: String?
    @NSManaged public var members: NSSet?

}

// MARK: Generated accessors for members
extension SharedCalendar {

    @objc(addMembersObject:)
    @NSManaged public func addToMembers(_ value: FamilyMember)

    @objc(removeMembersObject:)
    @NSManaged public func removeFromMembers(_ value: FamilyMember)

    @objc(addMembers:)
    @NSManaged public func addToMembers(_ values: NSSet)

    @objc(removeMembers:)
    @NSManaged public func removeFromMembers(_ values: NSSet)

}

extension SharedCalendar : Identifiable {

}
