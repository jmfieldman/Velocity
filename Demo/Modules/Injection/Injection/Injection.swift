//
//  Injection.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
import CoasterDataManagerImpl
@_exported import Inject
import ParkUI
import ParkUIImpl
import UnitTestExampleManager
import UnitTestExampleManagerImpl

public extension InjectionManager {
    static func registerInjections() {
        InjectionManager.unsafeRegister(CoasterDataManager.self) { CoasterDataManagerImpl() }
        InjectionManager.unsafeRegister(UnitTestExampleManager.self) { UnitTestExampleManagerImpl() }
    }

    static func activateInjections() {
        _ = Inject(CoasterDataManager.self)
        _ = Inject(UnitTestExampleManager.self)
    }
}

public extension BuilderManager {
    @MainActor static func registerBuilders() {
        BuilderManager.unsafeRegister(ParkListViewControllerBuilder.self) { ParkListViewControllerImpl(builder: $0 as! ParkListViewControllerBuilder) }
    }
}
