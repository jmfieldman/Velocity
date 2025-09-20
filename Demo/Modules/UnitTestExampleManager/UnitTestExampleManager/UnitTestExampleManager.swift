//
//  UnitTestExampleManager.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
import CoasterModels
import CombineEx
import Foundation

public protocol UnitTestExampleManager {
    /// Stream count of parks from the database
    func streamParkCount() -> AnyPublisher<Int, CoasterDataError>
}
