//
//  FamilyMemberCalendar+CoreDataProperties.swift
//  
//
//  Created by Mark Dias on 18/11/2025.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias FamilyMemberCalendarCoreDataPropertiesSet = NSSet

extension FamilyMemberCalendar {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FamilyMemberCalendar> {
        return NSFetchRequest<FamilyMemberCalendar>(entityName: "FamilyMemberCalendar")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var calendarID: String?
    @NSManaged public var calendarName: String?
    @NSManaged public var calendarColorHex: String?
    @NSManaged public var isAutoLinked: Bool
    @NSManaged public var familyMember: FamilyMember?

}

extension FamilyMemberCalendar : Identifiable {

}
