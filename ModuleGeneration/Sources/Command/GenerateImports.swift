//
//  GenerateImports.swift
//  Copyright © 2024 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities
import ModuleManagementLib
import Yams

extension ModuleGenerationCommand {
  final class GenerateImports: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Generate imports.yml files"
    )

    @OptionGroup var commonOptions: CommonOptions

    @Option(help: "Root path to search for packages")
    public var searchPath: String = "."

    func run() async throws {
      setVerbosity(commonOptions.verbosity)

      let fullSearchPath = searchPath.prependingCurrentDirectory()
      let projectPath = commonOptions.projectPath?.prependingCurrentDirectory() ?? FileManager.default.currentDirectoryPath

      // Verify path exists
      guard FileManager.default.directoryExists(atPath: fullSearchPath) else {
        throwError(.pathNotFound, "Directory not found at search path: \(fullSearchPath)")
      }

      guard FileManager.default.directoryExists(atPath: projectPath) else {
        throwError(.pathNotFound, "Directory not found at project path: \(projectPath)")
      }

      let packages = ModulePackageManager.packages(
        named: commonOptions.packageFileName,
        root: fullSearchPath,
        absoluteProjectPath: projectPath
      )

      vprint(.normal, "Regenerate imports for \(packages.count) package\(packages.count == 1 ? "" : "s")", "🔧")

      packages.sorted { $0.name < $1.name }.forEach { package in
        package.modules.values.sorted { $0.name < $1.name }.forEach { module in
          vprint(.debug, "Regenerate imports for \(module.name)", "🔧")
          module.regenerateImportsFile(ignoreFilenames: [])
        }
      }
    }
  }
}
