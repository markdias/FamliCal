//
//  RecentSearch+CoreDataProperties.swift
//  
//
//  Created by Mark Dias on 21/11/2025.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias RecentSearchCoreDataPropertiesSet = NSSet

extension RecentSearch {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecentSearch> {
        return NSFetchRequest<RecentSearch>(entityName: "RecentSearch")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var query: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var address: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double

}

extension RecentSearch : Identifiable {

}
