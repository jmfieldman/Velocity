//
//  Injection.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
import CoasterDataManagerImpl
@_exported import Inject

public extension InjectionManager {
    static func registerInjections() {
        InjectionManager.register(CoasterDataManager.self) { CoasterDataManagerImpl() }
    }
}
