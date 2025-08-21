//
//  CoasterDataManagerImpl.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterCoreDataModel
import CoasterDataManager
import CoasterModels
import CombineEx
import CoreData
import Foundation
import Slate

public final class CoasterDataManagerImpl: CoasterDataManager {
    let slate = Slate()

    public private(set) lazy var refreshParksAction = Action<Void, Void, CoasterDataError> { [weak self] _ in
        self?.refreshParksPublisher().eraseToAnyDeferredPublisher() ?? .just(())
    }

    public init() {
        let managedObjectModelURL = Bundle(for: CoasterDataModelBeacon.self)
            .url(forResource: "CoasterDataModel", withExtension: "momd")!
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
    func refreshParksPublisher() -> AnyDeferredFuture<Void, CoasterDataError> {
        lastParkUpdate()
            .flatMap { [weak self] lastDate -> AnyDeferredFuture<Void, CoasterDataError> in
                guard let self else {
                    return .just(())
                }

                if lastDate != Date.distantPast, Date().timeIntervalSince(lastDate) < 300 {
                    return .just(())
                }

                return fetchRemoteParks()
                    .flatMap { [weak self] parks in
                        self?.insertParks(parks) ?? .just(())
                    }
                    .eraseToAnyDeferredFuture()
            }.eraseToAnyDeferredFuture()
    }

    public func streamParks() -> AnyPublisher<[Park], CoasterDataError> {
        slate.stream { $0.sort(\.owner).sort(\.id) }
            .map(\.values)
            .mapError { CoasterDataError.databaseError($0) }
            .eraseToAnyPublisher()
    }
}
