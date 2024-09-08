//
//  Pull.swift
//  Copyright © 2024 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities

extension DependencyMagnetCommand {
  /// This subcommand pulls the dependencies into the current
  /// directory.
  final class Pull: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Pull dependencies"
    )

    @OptionGroup var commonOptions: CommonOptions

    /// Execute the pull command
    func run() async throws {
      setVerbosity(commonOptions.verbosity)

      let dependenciesConfig = DependenciesConfig.from(filePath: commonOptions.config)

      // Verify at least one dependency exists
      guard (dependenciesConfig.dependencies ?? []).count > 0 else {
        throwError(.noDependencies, "No dependencies found in dependencies config file \(commonOptions.config)")
      }

      DependencyPull().pull(
        dependencies: dependenciesConfig.dependencies ?? [],
        workspacePath: commonOptions.workspacePath,
        outputPath: commonOptions.outputPath
      )
    }
  }
}
