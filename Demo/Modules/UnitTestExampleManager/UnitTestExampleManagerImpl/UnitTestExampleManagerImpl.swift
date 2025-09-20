//
//  UnitTestExampleManagerImpl.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
import CoasterModels
import CombineEx
import CoreData
import Foundation
import Inject
import Slate
import UnitTestExampleManager

public final class UnitTestExampleManagerImpl: UnitTestExampleManager {
    let coasterDataManager: CoasterDataManager = Inject()

    public init() {}
}

public extension UnitTestExampleManagerImpl {
    func streamParkCount() -> AnyPublisher<Int, CoasterDataError> {
        coasterDataManager.streamParks().map(\.count).eraseToAnyPublisher()
    }
}
