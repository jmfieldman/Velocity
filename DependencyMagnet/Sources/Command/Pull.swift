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
            try DependencyPull().execute(
                with: DependencyPullOptions(
                    config: commonOptions.config,
                    workspacePath: commonOptions.workspacePath,
                    outputPath: commonOptions.outputPath
                )
            )
        }
    }
}
