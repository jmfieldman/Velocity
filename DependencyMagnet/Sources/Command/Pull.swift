//
//  Pull.swift
//  Copyright © 2024 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities
import Yams

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

      // Verify config exists
      guard FileManager.default.fileExists(atPath: commonOptions.config) else {
        throwError(.configNotFound, "Config file not found at \(commonOptions.config)")
      }

      // Decode config
      let dependenciesConfigData: Data
      let dependenciesConfig: DependenciesConfig
      do {
        dependenciesConfigData = try Data(contentsOf: commonOptions.config.prependingCurrentDirectory().fileURL())
        dependenciesConfig = try YAMLDecoder().decode(DependenciesConfig.self, from: dependenciesConfigData)
      } catch {
        throwError(.configNotDecodable, error.localizedDescription)
      }

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
