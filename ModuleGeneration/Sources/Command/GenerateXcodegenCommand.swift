//
//  GenerateXcodegenCommand.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import Foundation
import InternalUtilities
import ModuleGenerationLib
import ModuleManagementLib

extension ModuleGenerationCommand {
    final class GenerateXcodegenCommand: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Generate Xcodegen project-modules.yml"
        )

        @OptionGroup var commonOptions: CommonOptions

        @Flag(name: [.long], help: "Force imports.yml regeneration for all modules")
        public var regenImports: Bool = false

        @Flag(name: [.long], help: "Regenerate module info.plist files if needed")
        public var regenInfoPlists: Bool = false

        @Option(help: "Root path for modules detection and file generation")
        public var rootPath: String

        @Option(help: "Override the generated yml filename")
        public var outputFilename: String = "project-modules.yml"

        @Option(help: "Comma-delimited list of suported platforms (options: iOS, tvOS, watchOS, visionOS, macOS, macCatalyst)")
        public var platforms: String = "iOS"

        @Option(help: "Path to the dependencies.yml file that lists the dependencies for this project")
        public var dependenciesConfig: String = "Dependencies/dependencies.yml"

        func run() async throws {
            setVerbosity(commonOptions.verbosity)
            try GenerateXcodegen.execute(
                with: GenerateXcodegenOptions(
                    rootPath: rootPath,
                    regenImports: regenImports,
                    regenInfoPlists: regenInfoPlists,
                    outputFilename: outputFilename,
                    platforms: platforms,
                    dependenciesConfig: dependenciesConfig,
                    packageFileName: commonOptions.packageFileName
                )
            )
        }
    }
}
