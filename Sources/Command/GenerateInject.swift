//
//  GenerateInject.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import Foundation
import InternalUtilities
import ModuleGenerationLib
import ModuleManagementLib

extension Velocity {
    final class GenerateInject: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Generate Inject extension for a set of modules"
        )

        @OptionGroup var commonOptions: CommonOptions

        @Option(help: "Root path for modules detection")
        public var modulesPath: String

        @Option(help: "The swift file that will be output (including path)")
        public var outputFile: String

        @Flag(name: [.long], help: "Use @MainActor on injections")
        public var injectMainActor: Bool = false

        @Option(help: "The name of the function that will register injections")
        public var injectFunctionName: String = "registerInjections"

        @Option(help: "The name of the function that will register builders")
        public var builderFunctionName: String = "registerBuilders"

        @Option(help: "Override the normal package file name (\(kPathPackageYml))")
        public var packageFileName: String = kPathPackageYml

        func run() async throws {
            setVerbosity(commonOptions.verbosity)
            try ModuleGenerationLib.GenerateInject.execute(
                with: GenerateInjectOptions(
                    modulesPath: modulesPath,
                    outputFile: outputFile,
                    injectFunctionName: injectFunctionName,
                    injectMainActor: injectMainActor,
                    builderFunctionName: builderFunctionName,
                    packageFileName: packageFileName
                )
            )
        }
    }
}
