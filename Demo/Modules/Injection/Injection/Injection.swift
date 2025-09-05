//
//  Injection.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
import CoasterDataManagerImpl
@_exported import Inject
import ParkUI
import ParkUIImpl

public extension InjectionManager {
    static func registerInjections() {
        InjectionManager.unsafeRegister(CoasterDataManager.self) { CoasterDataManagerImpl() }
    }
}

public extension BuilderManager {
    @MainActor static func registerBuilders() {
        BuilderManager.unsafeRegister(ParkListViewControllerBuilder.self) { ParkListViewControllerImpl(builder: $0 as! ParkListViewControllerBuilder) }
    }
}
