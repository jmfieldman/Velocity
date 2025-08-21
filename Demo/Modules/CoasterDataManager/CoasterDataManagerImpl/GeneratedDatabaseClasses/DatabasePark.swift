//
//  DatabasePark.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterModels
import CoreData
import Foundation
import Slate

@objc(DatabasePark)
public final class DatabasePark: NSManagedObject, Park.ManagedPropertyProviding {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DatabasePark> {
        NSFetchRequest<DatabasePark>(entityName: "Park")
    }

    @nonobjc static func create(in moc: NSManagedObjectContext) -> DatabasePark? {
        NSEntityDescription.entity(forEntityName: "Park", in: moc).flatMap {
            DatabasePark(entity: $0, insertInto: moc)
        }
    }

    @NSManaged public var id: Int64
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var name: String?
    @NSManaged public var owner: String?
}

extension DatabasePark: SlateObjectConvertible {
    /**
     Instantiates an immutable Slate class from the receiving Core Data class.
     */
    public var slateObject: SlateObject {
        Park(managedObject: self)
    }
}

extension Park: @retroactive SlateObject {
    public static let __slate_managedObjectType: NSManagedObject.Type = DatabasePark.self
}

extension Park: @retroactive SlateManagedObjectRelating {
    public typealias ManagedObjectType = DatabasePark
}

public extension SlateRelationshipResolver where SO: Park {}
