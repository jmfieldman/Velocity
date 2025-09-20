//
//  UnitTestExampleManagerTests.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
@testable import CoasterDataManagerTestHelpers
@testable import CoasterModels
import CombineEx
import CoreData
import Cuckoo
import Foundation
import Inject
import Slate
import Testing
import UnitTestExampleManager
import UnitTestExampleManagerImpl

@Suite(.timeLimit(.minutes(1)))
struct UnitTestExampleManagerTests {
    let mockCoasterDataManager: MockCoasterDataManager
    let unitTestExampleManagerImpl: UnitTestExampleManager

    init() {
        let mockCoasterDataManager = MockCoasterDataManager()

        InjectionManager.register(CoasterDataManager.self) { mockCoasterDataManager }

        self.mockCoasterDataManager = mockCoasterDataManager
        self.unitTestExampleManagerImpl = UnitTestExampleManagerImpl()
    }

    @Test func mockDataManagerOutput() throws {
        let park1 = Park(id: 1, lastUpdated: Date(), latitude: 0, longitude: 0, name: "1", owner: "1")

        let mockedArray = AnyPublisher<[Park], CoasterDataError>.just([park1, park1, park1])
        stub(mockCoasterDataManager) { stub in
            when(stub.streamParks()).thenReturn(mockedArray)
        }

        var result = 0
        _ = unitTestExampleManagerImpl.streamParkCount().sink { _ in

        } receiveValue: { val in
            result = val
        }

        #expect(result == 3)
    }
}
