//
//  CoasterDataManagerImpl.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterCoreDataModel
import CoasterDataManager
import CombineEx
import CoreData
import Foundation
import Slate

public final class CoasterDataManagerImpl: CoasterDataManager {
    let slate = Slate()

    public private(set) lazy var refreshParksAction = Action<Void, Void, CoasterDataError> { [weak self] _ in
        .just(())
    }

    public init() {
        let managedObjectModelURL = Bundle(for: CoasterDataModelBeacon.self)
            .url(forResource: "CoasterDataModel", withExtension: "mom")!
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let databaseDirPath = documentsPath.appendingPathComponent("coaster_db")

        slate.configure(
            managedObjectModelUrl: managedObjectModelURL,
            persistentStoreType: NSSQLiteStoreType,
            persistentStoreUrl: databaseDirPath.appendingPathComponent("coaster.sqlite"),
            wipeDirectoryAndRetryOnFailure: true
        ) { _, error in
            if let error {
                fatalError("Error loading coaster db: \(error)")
            }
        }
    }
}

extension CoasterDataManagerImpl {
//    func refreshParksPublisher() -> AnyDeferredPublisher<Void, CoasterDataError> {
//        DeferredFuture.withTask { [weak self] () async throws(CoasterDataError) in
//            do {
//                let parks = try await self?.fetchRemoteParks()
//            } catch {
//                throw CoasterDataError.networkError(error)
//            }
//        }.eraseToAnyDeferredPublisher()
//    }
}
