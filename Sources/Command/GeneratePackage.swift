//
//  GeneratePackage.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import Foundation
import InternalUtilities
import ModuleGenerationLib
import ModuleManagementLib

extension VelocityCommand {
    final class GeneratePackage: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Generate Package.swift file"
        )

        @OptionGroup var commonOptions: CommonOptions

        @Option(help: "Override the normal package file name (package.yml)")
        public var packageFileName: String = "package.yml"

        @Option(help: "Specify the project path (if not the current working directory)")
        public var projectPath: String? = nil

        @Flag(name: [.long], help: "Force imports.yml regeneration for all modules")
        public var regenImports: Bool = false

        @Option(help: "Root path for package generation")
        public var rootPath: String

        @Option(help: "Swift Tools version")
        public var swiftToolsVersion: String = "5.8"

        @Option(help: "Declare the comma-delimited supported platforms list (e.g. \".macOS(.v12), .iOS(v17)\")")
        public var platforms: String

        @Option(help: "Path to the dependencies.yml file that lists the dependencies for this project")
        public var dependenciesConfig: String = "Dependencies/dependencies.yml"

        @Option(help: "The output path of the dependency_magnet command used to create local packages. If not provided then no local packages will be used.")
        public var dependencyOutputPath: String?

        @Option(help: "Override the generated package name (otherwise will use the root basename)")
        public var packageName: String?

        func run() async throws {
            setVerbosity(commonOptions.verbosity)
            try ModuleGenerationLib.GeneratePackage.execute(
                with: GeneratePackageOptions(
                    regenImports: regenImports,
                    rootPath: rootPath,
                    swiftToolsVersion: swiftToolsVersion,
                    platforms: platforms,
                    dependenciesConfig: dependenciesConfig,
                    dependencyOutputPath: dependencyOutputPath,
                    packageName: packageName,
                    packageFileName: packageFileName
                )
            )
        }
    }
}
