//
//  CoasterDataManagerImpl.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterCoreDataModel
import CoasterDataManager
import CoreData
import Foundation
import Slate

public final class CoasterDataManagerImpl: CoasterDataManager {
    private let slate = Slate()

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
