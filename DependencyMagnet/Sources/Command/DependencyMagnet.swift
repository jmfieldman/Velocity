//
//  DependencyMagnet.swift
//  Copyright © 2024 Jason Fieldman.
//

import ArgumentParser
import InternalUtilities

/// The main command collection for the command line tool.
@main struct DependencyMagnetCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Contains commands for the dependency magnet suite.",
        subcommands: [
            Pull.self,
        ]
    )
}
