//
//  VelocityCommand.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import InternalUtilities

/// The main command collection for the command line tool.
@main struct Velocity: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Contains commands for the Velocity package.",
        subcommands: [
            GenerateImports.self,
            GenerateInject.self,
            GeneratePackage.self,
            GenerateXcodegenModules.self,
            GenerateXcodegenDeps.self,
            PullDependencies.self,
            SanitizeXcodegenProject.self,
        ]
    )
}
