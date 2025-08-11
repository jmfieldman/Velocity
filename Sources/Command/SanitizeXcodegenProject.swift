//
//  SanitizeXcodegenProject.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import Foundation
import InternalUtilities
import ModuleGenerationLib
import ModuleManagementLib

extension Velocity {
    final class SanitizeXcodegenProject: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Sanitize xcodegen-based .xcodeproj file timestamps and remove modified products."
        )

        @OptionGroup var commonOptions: CommonOptions

        @Option(help: "Override the normal package file name (\(kPathPackageYml))")
        public var packageFileName: String = kPathPackageYml

        @Option(help: "Specify the path to the .xcodeproj file")
        public var xcodeprojPath: String

        @Option(help: "Specify the path to the modules xcodegen .yml file")
        public var modulesYmlPath: String

        @Option(help: "Comma-delimited paths to the project .yml files used by xcodegen to create the .xcodeproj")
        public var projectYmlPaths: String

        @Option(help: ".xcodeproj configuration to clean (default: Debug)")
        public var xcodeConfiguration: String = "Debug"

        @Option(help: "Final app product name (only required if different from the xcodeproj file name)")
        public var appName: String? = nil

        func run() async throws {
            setVerbosity(commonOptions.verbosity)
            try ModuleGenerationLib.SanitizeXcodegenProject.execute(
                with: SanitizeXcodegenProjectOptions(
                    packageFileName: packageFileName,
                    xcodeprojPath: xcodeprojPath,
                    modulesYmlPath: modulesYmlPath,
                    projectYmlPaths: projectYmlPaths,
                    xcodeConfiguration: xcodeConfiguration,
                    appName: appName
                )
            )
        }
    }
}
