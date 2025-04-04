//
//  GenerateImportsCommand.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import Foundation
import InternalUtilities
import ModuleGenerationLib
import ModuleManagementLib

extension ModuleGenerationCommand {
    final class GenerateImportsCommand: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Generate imports.yml files"
        )

        @OptionGroup var commonOptions: CommonOptions

        @Option(help: "Root path to search for packages")
        public var searchPath: String = "."

        func run() async throws {
            setVerbosity(commonOptions.verbosity)
            try GenerateImports.execute(
                with: GenerateImportsOptions(
                    searchPath: searchPath,
                    projectPath: commonOptions.projectPath,
                    packageFilename: commonOptions.packageFileName
                )
            )
        }
    }
}
