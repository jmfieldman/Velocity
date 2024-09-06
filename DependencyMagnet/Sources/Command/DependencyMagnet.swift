//
//  DependencyMagnet.swift
//  Copyright © 2023 Jason Fieldman.
//

import ArgumentParser

/// The main command collection for the command line tool.
@main struct DependencyMagnetCommand: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "Contains commands for the dependency magnet suite.",
    subcommands: [
      Pull.self,
    ]
  )
}
