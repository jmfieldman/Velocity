//
//  GenerateXcodegenModules.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import Foundation
import InternalUtilities
import ModuleGenerationLib
import ModuleManagementLib

extension Velocity {
    final class GenerateXcodegenModules: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Generate Xcodegen project-modules.yml"
        )

        @OptionGroup var commonOptions: CommonOptions

        @Option(help: "Override the normal package file name (\(kPathPackageYml))")
        public var packageFileName: String = kPathPackageYml

        @Option(help: "Specify the project path (if not the current working directory)")
        public var projectPath: String? = nil

        @Flag(name: [.long], help: "Force imports.yml regeneration for all modules")
        public var regenImports: Bool = false

        @Flag(name: [.long], help: "Regenerate module info.plist files if needed")
        public var regenInfoPlists: Bool = false

        @Flag(name: [.long], help: "Modules default to static frameworks instead of dynamic frameworks")
        public var defaultStatic: Bool = false

        @Option(help: "Root path for modules detection and file generation")
        public var rootPath: String

        @Option(help: "Override the generated yml filename")
        public var outputFilename: String = "project-modules.yml"

        @Option(help: "Comma-delimited list of suported platforms (options: iOS, tvOS, watchOS, visionOS, macOS, macCatalyst)")
        public var platforms: String = "iOS"

        @Option(help: "Include this output filename to generate an optional Cuckoo config file (Cuckoofile.toml) for mock generation")
        public var cuckooOutputFile: String? = nil

        @Option(help: "Path to the dependencies.yml file that lists the dependencies for this project")
        public var dependenciesConfig: String = kPathDependencyConfig

        func run() async throws {
            setVerbosity(commonOptions.verbosity)
            try ModuleGenerationLib.GenerateXcodegenModules.execute(
                with: GenerateXcodegenModulesOptions(
                    rootPath: rootPath,
                    regenImports: regenImports,
                    regenInfoPlists: regenInfoPlists,
                    outputFilename: outputFilename,
                    platforms: platforms,
                    dependenciesConfig: dependenciesConfig,
                    packageFileName: packageFileName,
                    cuckooOutputFile: cuckooOutputFile,
                    defaultStatic: defaultStatic
                )
            )
        }
    }
}
