//
//  GenerateResources.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import Foundation
import InternalUtilities
import ModuleGenerationLib
import ModuleManagementLib

extension Velocity {
    final class GenerateResources: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Generate resource code extensions for each resource modules"
        )

        @OptionGroup var commonOptions: CommonOptions

        @Option(help: "Root path for modules detection")
        public var modulesPath: String

        @Option(help: "Override the normal package file name (\(kPathPackageYml))")
        public var packageFileName: String = kPathPackageYml

        func run() async throws {
            setVerbosity(commonOptions.verbosity)
            try ModuleGenerationLib.GenerateResources.execute(
                with: GenerateResourcesOptions(
                    modulesPath: modulesPath,
                    packageFileName: packageFileName
                )
            )
        }
    }
}
