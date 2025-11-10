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

        @Option(help: "Set this value to the swift package name that the resource modules are inside of (if applicable)")
        public var swiftPackage: String? = nil

        @Option(help: "Override the normal package file name (\(kPathPackageYml))")
        public var packageFileName: String = kPathPackageYml

        @Flag(name: [.long], help: "Do not generate SwiftUI asset helpers")
        public var noSwiftUiAssets: Bool = false

        @Option(help: "File to output list of resource directories (optional)")
        public var outputResourceManifest: String? = nil

        func run() async throws {
            setVerbosity(commonOptions.verbosity)
            try ModuleGenerationLib.GenerateResources.execute(
                with: GenerateResourcesOptions(
                    modulesPath: modulesPath,
                    swiftPackage: swiftPackage,
                    packageFileName: packageFileName,
                    noSwiftUiAssets: noSwiftUiAssets,
                    outputResourceManifest: outputResourceManifest
                )
            )
        }
    }
}
