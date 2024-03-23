//
//  CommonOptions.swift
//  Copyright © 2023 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation

/// Common options for ParsableCommands
public struct CommonOptions: ParsableArguments {
  @Flag(name: [.long], help: "Print verbose output")
  public var verbose: Bool = false

  @Flag(name: [.long], help: "Quiet all normal output")
  public var quiet: Bool = false

  @Flag(name: [.long], help: "Print debug output (higher than verbose)")
  public var debug: Bool = false

  @Option(help: "Path to config file")
  public var config: String = "Dependencies/dependencies.yml"

  @Option(help: "Workspace path")
  public var workspacePath: String = ".dependency_magnet"

  @Option(help: "Output path")
  public var outputPath: String = "Dependencies"

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
