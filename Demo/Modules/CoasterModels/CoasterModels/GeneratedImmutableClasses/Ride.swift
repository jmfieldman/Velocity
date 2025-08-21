//
//  Ride.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoreData
import Foundation

public final class Ride: Sendable {
    // -- Attribute Declarations --
    public let id: Int
    public let isOpen: Bool
    public let land: String?
    public let lastUpdated: Date
    public let name: String
    public let waitTime: Int

    // -- Attribute Names --

    public enum Attributes {
        public static let id = "id"
        public static let isOpen = "isOpen"
        public static let land = "land"
        public static let lastUpdated = "lastUpdated"
        public static let name = "name"
        public static let waitTime = "waitTime"
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
        self.isOpen = managedObject.isOpen
        self.land = managedObject.land
        self.lastUpdated = { let t: Date? = managedObject.lastUpdated
            return t!
        }()
        self.name = { let t: String? = managedObject.name
            return t!
        }()
        self.waitTime = Int(managedObject.waitTime)
    }

    /**
     Allow the creation of a Slate-exposed class/struct with all of its parameters.
     Note that this is internal -- this is for use only in unit tests (using the
     @testable import directive).  You should never create values with this
     constructor in normal code.
     */
    init(
        id: Int,
        isOpen: Bool,
        land: String?,
        lastUpdated: Date,
        name: String,
        waitTime: Int
    ) {
        // Internally created objects have no real managed object ID
        self.slateID = NSManagedObjectID()

        self.id = id
        self.isOpen = isOpen
        self.land = land
        self.lastUpdated = lastUpdated
        self.name = name
        self.waitTime = waitTime
    }

    // -- Substruct Definitions
}

public extension Ride {
    protocol ManagedPropertyProviding: NSManagedObject {
        var id: Int64 { get }
        var isOpen: Bool { get }
        var land: String? { get }
        var lastUpdated: Date? { get }
        var name: String? { get }
        var waitTime: Int64 { get }
    }
}

extension Ride: Equatable {
    public static func == (lhs: Ride, rhs: Ride) -> Bool {
        (lhs.slateID == rhs.slateID) &&
            (lhs.id == rhs.id) &&
            (lhs.isOpen == rhs.isOpen) &&
            (lhs.land == rhs.land) &&
            (lhs.lastUpdated == rhs.lastUpdated) &&
            (lhs.name == rhs.name) &&
            (lhs.waitTime == rhs.waitTime)
    }
}
