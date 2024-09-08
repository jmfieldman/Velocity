//
//  ModuleGeneration.swift
//  Copyright © 2024 Jason Fieldman.
//

import ArgumentParser
import InternalUtilities

/// The main command collection for the command line tool.
@main struct ModuleGenerationCommand: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Contains commands for module generation and handling.",
    subcommands: [
      GenerateImports.self,
      GeneratePackage.self,
    ]
  )
}
