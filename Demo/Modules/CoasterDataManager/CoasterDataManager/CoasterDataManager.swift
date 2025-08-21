//
//  CoasterDataManager.swift
//  Copyright © 2025 Jason Fieldman.
//

import CombineEx
import Foundation

public enum CoasterDataError: Error {
    case networkError(Error)
    case databaseError(Error)
}

public protocol CoasterDataManager {
    /// Trigger this action to refresh the local database with the remote parks data
    var refreshParksAction: Action<Void, Void, CoasterDataError> { get }
}
