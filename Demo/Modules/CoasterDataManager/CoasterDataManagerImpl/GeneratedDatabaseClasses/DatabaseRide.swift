//
//  DatabaseRide.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterModels
import CoreData
import Foundation
import Slate

@objc(DatabaseRide)
public final class DatabaseRide: NSManagedObject, Ride.ManagedPropertyProviding {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DatabaseRide> {
        NSFetchRequest<DatabaseRide>(entityName: "Ride")
    }

    @nonobjc static func create(in moc: NSManagedObjectContext) -> DatabaseRide? {
        NSEntityDescription.entity(forEntityName: "Ride", in: moc).flatMap {
            DatabaseRide(entity: $0, insertInto: moc)
        }
    }

    @NSManaged public var id: Int64
    @NSManaged public var isOpen: Bool
    @NSManaged public var land: String?
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var name: String?
    @NSManaged public var waitTime: Int64
}

extension DatabaseRide: SlateObjectConvertible {
    /**
     Instantiates an immutable Slate class from the receiving Core Data class.
     */
    public var slateObject: SlateObject {
        Ride(managedObject: self)
    }
}

extension Ride: @retroactive SlateObject {
    public static let __slate_managedObjectType: NSManagedObject.Type = DatabaseRide.self
}

extension Ride: @retroactive SlateManagedObjectRelating {
    public typealias ManagedObjectType = DatabaseRide
}

public extension SlateRelationshipResolver where SO: Ride {}
