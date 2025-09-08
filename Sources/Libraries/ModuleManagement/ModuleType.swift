//
//  ModuleType.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation

public enum ModuleType: String, Codable, CaseIterable {
    case main
    case impl
    case tests
    case testHelpers

    /// The directory name suffix used for this module type
    var suffix: String {
        switch self {
        case .main: ""
        case .impl: "Impl"
        case .tests: "Tests"
        case .testHelpers: "TestHelpers"
        }
    }

    /// Returns the full directory name for the module inside of a specfied
    /// package name
    func directory(for packageName: String) -> String {
        packageName.appending(suffix)
    }

    /// An array of sibling module types whose imports should be merged into
    /// ours when performing import graph cycle checks.
    func bridgedSiblingImports(hasPackageInjections: Bool) -> [ModuleType] {
        switch self {
        // Main imports Impl because of the injection pattern where protocols
        // defined in main will inject/instantiate their implementations, which
        // can in turn immediately require the instantiations of other injected
        // types. So anyone using a type in main can potentially depend on a
        // type in impl.
        case .main: hasPackageInjections ? [.impl] : []
        case .impl: []
        case .tests: []
        case .testHelpers: []
        }
    }

    /// This check is run on files inside of a module of this type, to ensure
    /// that there are files that qualify this modules as "active".
    var fileCheck: (String) -> Bool {
        switch self {
        case .main, .impl, .tests, .testHelpers:
            { $0.hasSuffix(".swift") }
        }
    }
}
