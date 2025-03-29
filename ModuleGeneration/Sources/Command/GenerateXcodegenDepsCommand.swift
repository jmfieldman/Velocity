//
//  GenerateXcodegenDepsCommand.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import Foundation
import InternalUtilities
import ModuleGenerationLib
import ModuleManagementLib

extension ModuleGenerationCommand {
    final class GenerateXcodegenDepsCommand: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Generate Xcodegen project-dependencies.yml from dependencies.yml file"
        )

        @OptionGroup var commonOptions: CommonOptions

        @Option(help: "Override the generated yml filename")
        public var outputFilename: String = "project-dependencies.yml"

        @Option(help: "Path to the dependencies.yml file that lists the dependencies for this project")
        public var dependenciesConfig: String = "Dependencies/dependencies.yml"

        @Option(help: "The output path of the dependency_magnet command used to create local packages, without the Package directory suffix. If not provided then no local packages will be used. If using the default setup this should be \"Dependencies\".")
        public var dependencyOutputPath: String?

        func run() async throws {
            setVerbosity(commonOptions.verbosity)
            try GenerateXcodegenDeps.execute(
                with: GenerateXcodegenDepsOptions(
                    outputFilename: outputFilename,
                    dependenciesConfig: dependenciesConfig,
                    dependencyOutputPath: dependencyOutputPath
                )
            )
        }
    }
}
