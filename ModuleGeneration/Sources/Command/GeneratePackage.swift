//
//  GeneratePackage.swift
//  Copyright © 2024 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities
import ModuleManagementLib
import Yams

extension ModuleGenerationCommand {
  final class GeneratePackage: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Generate Package.swift file"
    )

    @OptionGroup var commonOptions: CommonOptions

    @Flag(name: [.long], help: "Force imports.yml regeneration for all modules")
    public var regenImports: Bool = false

    @Option(help: "Root path for package generation")
    public var rootPath: String

    @Option(help: "Swift Tools version")
    public var swiftToolsVersion: String = "5.8"

    @Option(help: "Declare the comma-delimited supported platforms list (e.g. \".macOS(.v12), .iOS(v17)\")")
    public var platforms: String

    @Option(help: "Path to the dependencies.yml file that lists the dependencies for this Package")
    public var dependenciesConfig: String = "dependencies.yml"

    @Option(help: "Override the package name (otherwise will use the root basename)")
    public var packageName: String?

    func run() async throws {
      setVerbosity(commonOptions.verbosity)

      let projectPath = rootPath.prependingCurrentDirectory()

      // Verify root path exists
      guard FileManager.default.directoryExists(atPath: projectPath) else {
        throwError(.pathNotFound, "Directory not found at root path: \(projectPath)")
      }

      let packages = ModulePackageManager.packages(
        named: commonOptions.packageFileName,
        root: projectPath,
        absoluteProjectPath: projectPath
      )

      guard packages.count > 0 else {
        vprint(.normal, "No packages found at root path: \(projectPath)")
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

      vprint(.normal, "Generating \(rootPath)/Package.swift", "🔧")

      let packageContents = kPackageSwiftTemplate
        .replacingOccurrences(of: "{SWIFT_TOOLS}", with: swiftToolsVersion)
        .replacingOccurrences(of: "{PACKAGE_NAME}", with: gen_PACKAGE_NAME())
        .replacingOccurrences(of: "{PLATFORMS}", with: platforms)
        .replacingOccurrences(of: "{DEPENDENCIES}", with: gen_DEPENDENCIES())
        .replacingOccurrences(of: "{TARGETS}", with: gen_TARGETS())

      try! packageContents.write(
        toFile: "\(projectPath)/Package.swift",
        atomically: true,
        encoding: .utf8
      )
    }

    func gen_PACKAGE_NAME() -> String {
      packageName ?? rootPath.lastPathComponent
    }

    func gen_DEPENDENCIES() -> String {
      guard FileManager.default.fileExists(atPath: dependenciesConfig) else {
        vprint(.normal, "Warning, no external dependencies config found at path: \(dependenciesConfig)", "❗")
        return ""
      }

      let dependenciesConfig = DependenciesConfig.from(filePath: dependenciesConfig)
      guard let dependencies = dependenciesConfig.dependencies, dependencies.count > 0 else {
        return ""
      }

      return dependencies.map { dependency -> String in
        dependency.packageString
      }.joined(separator: "\n")
    }

    func gen_TARGETS() -> String {
      ""
    }
  }
}

let kPackageSwiftTemplate = """
// swift-tools-version:{SWIFT_TOOLS}

import PackageDescription

let package = Package(
  name: "{PACKAGE_NAME}",
  platforms: [
    {PLATFORMS}
  ],
  products: [
    {PRODUCTS}
  ],
  dependencies: [
    {DEPENDENCIES}
  ],
  targets: [
    {TARGETS}
  ]
)
"""
