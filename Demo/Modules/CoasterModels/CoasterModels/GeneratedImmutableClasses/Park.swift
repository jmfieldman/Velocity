//
//  Park.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoreData
import Foundation

public final class Park: Sendable {
    // -- Attribute Declarations --
    public let id: Int
    public let latitude: Double
    public let longitude: Double
    public let name: String
    public let owner: String

    // -- Attribute Names --

    public enum Attributes {
        public static let id = "id"
        public static let latitude = "latitude"
        public static let longitude = "longitude"
        public static let name = "name"
        public static let owner = "owner"
    }

    public struct Relationships {}

    /**
      Each immutable data model object should have an associated SlateID (in the
      core data case, the NSManagedObjectID.  This is a cross-mutation identifier
      for the object.
     */
    public let slateID: NSManagedObjectID

    /**
     Instantiation is public so that Slate instances can create immutable objects
     from corresponding managed objects. You should never manually construct this in code.
     */
    public init(managedObject: ManagedPropertyProviding) {
        // Immutable objects should only be created inside Slate contexts
        // (by the Slate engine)
        guard Thread.current.threadDictionary["kThreadKeySlateQueryContext"] != nil else {
            fatalError("It is a programming error to instantiate an immutable Slate object from outside of a Slate query context.")
        }

        // All objects inherit the objectID
        self.slateID = managedObject.objectID

        // Attribute assignment
        self.id = Int(managedObject.id)
        self.latitude = managedObject.latitude
        self.longitude = managedObject.longitude
        self.name = { let t: String? = managedObject.name
            return t!
        }()
        self.owner = { let t: String? = managedObject.owner
            return t!
        }()
    }

    /**
     Allow the creation of a Slate-exposed class/struct with all of its parameters.
     Note that this is internal -- this is for use only in unit tests (using the
     @testable import directive).  You should never create values with this
     constructor in normal code.
     */
    init(
        id: Int,
        latitude: Double,
        longitude: Double,
        name: String,
        owner: String
    ) {
        // Internally created objects have no real managed object ID
        self.slateID = NSManagedObjectID()

        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.owner = owner
    }

    // -- Substruct Definitions
}

public extension Park {
    protocol ManagedPropertyProviding: NSManagedObject {
        var id: Int64 { get }
        var latitude: Double { get }
        var longitude: Double { get }
        var name: String? { get }
        var owner: String? { get }
    }
}

extension Park: Equatable {
    public static func == (lhs: Park, rhs: Park) -> Bool {
        (lhs.slateID == rhs.slateID) &&
            (lhs.id == rhs.id) &&
            (lhs.latitude == rhs.latitude) &&
            (lhs.longitude == rhs.longitude) &&
            (lhs.name == rhs.name) &&
            (lhs.owner == rhs.owner)
    }
}
