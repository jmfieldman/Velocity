//
//  GenerateXcodegen.swift
//  Copyright © 2024 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities
import ModuleManagementLib
import ProjectSpec
import Yams

extension ModuleGenerationCommand {
  final class GenerateXcodegen: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Generate Xcodegen project-modules.yml"
    )

    @OptionGroup var commonOptions: CommonOptions

    @Flag(name: [.long], help: "Force imports.yml regeneration for all modules")
    public var regenImports: Bool = false

    @Option(help: "Root path for modules detection and file generation")
    public var rootPath: String

    @Option(help: "Override the generated yml filename")
    public var outputFilename: String = "project-modules.yml"

    @Option(help: "Comma-delimited list of suported platforms (options: iOS, tvOS, watchOS, visionOS, macOS, macCatalyst)")
    public var platforms: String = "iOS"

    func run() async throws {
      setVerbosity(commonOptions.verbosity)

      let absoluteModuleBasePath = rootPath.prependingCurrentDirectory()
      let absoluteProjectPath = FileManager.default.currentDirectoryPath

      // Verify root path exists
      guard FileManager.default.directoryExists(atPath: absoluteModuleBasePath) else {
        throwError(.pathNotFound, "Module directory not found at path: \(rootPath)")
      }

      let supportedDestinations: [ProjectSpec.SupportedDestination] = platforms
        .components(separatedBy: ",")
        .map {
          guard let dest = ProjectSpec.SupportedDestination(rawValue: $0) else {
            throwError(.invalidArgument, "\($0) is not a valid platform -- options are (iOS, tvOS, watchOS, visionOS, macOS, macCatalyst)")
          }
          return dest
        }

      let packages = ModulePackageManager.packages(
        named: commonOptions.packageFileName,
        root: rootPath,
        absoluteProjectPath: absoluteProjectPath
      )

      guard packages.count > 0 else {
        vprint(.normal, "No packages found at root path: \(rootPath)")
        return
      }

      if regenImports {
        vprint(.normal, "Regenerate imports for \(packages.count) package\(packages.count == 1 ? "" : "s")", "🔧")
        packages.sorted { $0.name < $1.name }.forEach { package in
          package.modules.values.sorted { $0.name < $1.name }.forEach { module in
            vprint(.debug, "Regenerate imports for \(module.name)", "🔧")
            module.regenerateImportsFile(ignoreFilenames: [])
          }
        }
      }

      vprint(.normal, "Generating \(outputFilename)", "🔧")

      var targets: [String: [String: Any]] = [:]
      packages.sorted { $0.name < $1.name }.forEach { package in
        package.modules.values.sorted { $0.name < $1.name }.forEach { module in
          let target = ProjectSpec.Target(
            name: module.name,
            type: module.type == .tests ? .unitTestBundle : .framework,
            platform: .auto,
            supportedDestinations: supportedDestinations
          )

          targets[module.name] = target.toJSONValue() as? [String: Any]
        }
      }

      try! (try! Yams.dump(
        object: ["targets": targets],
        sortKeys: true
      )).removingEmptyYml().write(
        toFile: outputFilename,
        atomically: true,
        encoding: .utf8
      )
    }
  }
}

private extension String {
  func removingEmptyYml() -> String {
    components(separatedBy: .newlines)
      .filter { !($0.contains(": null") || $0.contains(": []") || $0.contains(": {}")) }
      .joined(separator: "\n")
  }
}
