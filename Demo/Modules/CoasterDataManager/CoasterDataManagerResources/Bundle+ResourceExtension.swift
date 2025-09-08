//
//  Bundle+ResourceExtension.swift
//  Copyright © 2025 Jason Fieldman.
//

import Foundation

public extension Bundle {
    private class CoasterDataManagerResourcesBeacon {}
    static let CoasterDataManagerResources = Bundle(for: CoasterDataManagerResourcesBeacon.self)
}
