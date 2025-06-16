//
//  GenerateImports.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import Foundation
import InternalUtilities
import ModuleGenerationLib
import ModuleManagementLib

extension VelocityCommand {
    final class GenerateImports: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Generate imports.yml files"
        )

        @OptionGroup var commonOptions: CommonOptions

        @Option(help: "Override the normal package file name (package.yml)")
        public var packageFileName: String = "package.yml"

        @Option(help: "Specify the project path (if not the current working directory)")
        public var projectPath: String? = nil

        @Option(help: "Root path to search for packages")
        public var searchPath: String = "."

        func run() async throws {
            setVerbosity(commonOptions.verbosity)
            try ModuleGenerationLib.GenerateImports.execute(
                with: GenerateImportsOptions(
                    searchPath: searchPath,
                    projectPath: projectPath,
                    packageFilename: packageFileName
                )
            )
        }
    }
}
