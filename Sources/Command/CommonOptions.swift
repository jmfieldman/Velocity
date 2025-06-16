//
//  CommonOptions.swift
//  Copyright © 2024 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities

/// Common options for ParsableCommands
public struct CommonOptions: ParsableArguments {
    @Flag(name: [.long], help: "Print verbose output")
    public var verbose: Bool = false

    @Flag(name: [.long], help: "Quiet all normal output")
    public var quiet: Bool = false

    @Flag(name: [.long], help: "Print debug output (higher than verbose)")
    public var debug: Bool = false

    public init() {}
}

public extension CommonOptions {
    var verbosity: Verbosity {
        if debug { return .debug }
        if verbose { return .verbose }
        if quiet { return .quiet }
        return .normal
    }
}
