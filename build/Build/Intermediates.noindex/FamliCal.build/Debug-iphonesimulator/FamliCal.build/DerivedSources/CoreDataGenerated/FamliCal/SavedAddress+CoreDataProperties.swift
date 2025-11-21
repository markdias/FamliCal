//
//  SavedAddress+CoreDataProperties.swift
//  
//
//  Created by Mark Dias on 21/11/2025.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias SavedAddressCoreDataPropertiesSet = NSSet

extension SavedAddress {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SavedAddress> {
        return NSFetchRequest<SavedAddress>(entityName: "SavedAddress")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var address: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double

}

extension SavedAddress : Identifiable {

}
