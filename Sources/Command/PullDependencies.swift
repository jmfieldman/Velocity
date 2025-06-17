//
//  PullDependencies.swift
//  Copyright © 2024 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities

extension Velocity {
    /// This subcommand pulls the dependencies into the current
    /// directory.
    final class PullDependencies: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Pull dependencies"
        )

        @OptionGroup var commonOptions: CommonOptions

        @Option(help: "Path to config file")
        public var dependenciesConfig: String = kPathDependencyConfig

        @Option(help: "Workspace path")
        public var workspacePath: String = kPathMagnetWorkspace

        @Option(help: "Output path")
        public var dependencyOutputPath: String = kPathDependencyOutput

        /// Execute the pull command
        func run() async throws {
            setVerbosity(commonOptions.verbosity)
            try DependencyPull().execute(
                with: DependencyPullOptions(
                    config: dependenciesConfig,
                    workspacePath: workspacePath,
                    outputPath: dependencyOutputPath
                )
            )
        }
    }
}
