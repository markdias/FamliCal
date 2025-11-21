//
//  Driver+CoreDataProperties.swift
//  
//
//  Created by Mark Dias on 21/11/2025.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias DriverCoreDataPropertiesSet = NSSet

extension Driver {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Driver> {
        return NSFetchRequest<Driver>(entityName: "Driver")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var phone: String?
    @NSManaged public var email: String?
    @NSManaged public var notes: String?
    @NSManaged public var travelTimeMinutes: Int16
    @NSManaged public var familyMemberId: UUID?
    @NSManaged public var travelEventIdentifier: String?
    @NSManaged public var events: NSSet?

}

// MARK: Generated accessors for events
extension Driver {

    @objc(addEventsObject:)
    @NSManaged public func addToEvents(_ value: FamilyEvent)

    @objc(removeEventsObject:)
    @NSManaged public func removeFromEvents(_ value: FamilyEvent)

    @objc(addEvents:)
    @NSManaged public func addToEvents(_ values: NSSet)

    @objc(removeEvents:)
    @NSManaged public func removeFromEvents(_ values: NSSet)

}

extension Driver : Identifiable {

}
