//
//  CoasterDataManagerImpl+Database.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
import CoasterModels
import CombineEx
import Foundation
import Slate

extension CoasterDataManagerImpl {
    func lastParkUpdate() -> AnyDeferredFuture<Date, CoasterDataError> {
        DeferredFuture.withTask(
            nonconformingErrorHandler: { .databaseError($0) }
        ) { [slate] () async throws in
            try await slate.query { context in
                try context[Park.self].fetchOne()?.lastUpdated ?? Date.distantPast
            }
        }.eraseToAnyDeferredFuture()
    }

    func insertParks(_ parkOwners: [WireParkOwner]) -> AnyDeferredFuture<Void, CoasterDataError> {
        DeferredFuture.withTask(
            nonconformingErrorHandler: { .databaseError($0) }
        ) { [slate] () async throws in
            try await slate.mutate { context in
                // Wipe all existing parks
                try context[DatabasePark.self].delete()
                let insertionDate = Date()

                for owner in parkOwners {
                    let ownerName = owner.name
                    for park in owner.parks {
                        let newPark = DatabasePark(context: context)
                        newPark.id = Int64(truncatingIfNeeded: park.id)
                        newPark.name = park.name
                        newPark.latitude = Double(park.latitude) ?? 0
                        newPark.longitude = Double(park.longitude) ?? 0
                        newPark.owner = ownerName
                        newPark.lastUpdated = insertionDate
                    }
                }
            }
        }.eraseToAnyDeferredFuture()
    }
}
