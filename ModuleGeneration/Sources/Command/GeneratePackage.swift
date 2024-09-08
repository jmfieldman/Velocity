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
    public var dependenciesConfig: String = "Dependencies/dependencies.yml"

    @Option(help: "The output path of the dependency_magnet command used to create local packages. If not provided then no local packages will be used.")
    public var dependencyOutputPath: String?

    @Option(help: "Override the generated package name (otherwise will use the root basename)")
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

      let packageManager = ModulePackageManager(packages: packages)

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
        .replacingOccurrences(of: "{PRODUCTS}", with: gen_PRODUCTS(packageManager: packageManager))
        .replacingOccurrences(of: "{DEPENDENCIES}", with: gen_DEPENDENCIES())
        .replacingOccurrences(of: "{TARGETS}", with: gen_TARGETS(packageManager: packageManager, projectPath: projectPath))

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
        guard dependency.keepRemote != true else {
          return dependency.packageString
        }

        // Determine the name of the dependency package
        let dependencyPackageName = dependency.inferredPackageName

        guard let dependencyOutputPath else {
          vprint(.normal, "Warning, no dependencyOutputPath was specified; \(dependencyPackageName) will use remote package", "❗")
          return dependency.packageString
        }

        let dependencyPackagePath = "\(dependencyOutputPath)/Packages/\(dependencyPackageName)"
        guard FileManager.default.directoryExists(atPath: dependencyPackagePath) else {
          vprint(.normal, "Warning, no local package exists at \(dependencyPackagePath); \(dependencyPackageName) will use remote package", "❗")
          return dependency.packageString
        }

        let path = dependencyPackagePath.prependingCurrentDirectory().relative(to: rootPath.prependingCurrentDirectory())
        return ".package(name: \"\(dependencyPackageName)\", path: \"\(path)\")"
      }.joined(separator: "\n")
    }

    func gen_TARGETS(
      packageManager: ModulePackageManager,
      projectPath: String
    ) -> String {
      var externalImports: [String: String] = [:]
      if
        FileManager.default.fileExists(atPath: dependenciesConfig),
        case let dependenciesConfig = DependenciesConfig.from(filePath: dependenciesConfig),
        let dependencies = dependenciesConfig.dependencies,
        dependencies.count > 0
      {
        for dependency in dependencies {
          dependency.libraries?.forEach {
            externalImports[$0] = ".product(name: \"\($0)\", package: \"\(dependency.inferredPackageName)\")"
          }
        }
      }

      var knownModules: Set<String> = []
      for package in packageManager.packages {
        for value in package.modules.values {
          knownModules.insert(value.name)
        }
      }

      var targets: [String] = []
      packageManager.packages.sorted { $0.name < $1.name }.forEach { package in
        package.modules.keys.sorted { $0.rawValue < $1.rawValue }.forEach { key in
          guard let module = package.modules[key] else { return }

          var deps: [String] = []
          for dep in packageManager.importGraph[module.name] ?? [] {
            if let externalImport = externalImports[dep.name] {
              deps.append(externalImport)
            } else if knownModules.contains(dep.name) {
              deps.append("\"\(dep.name)\"")
            }
          }

          let targetStr = """
          .target(
            name: "\(module.name)",
            dependencies: [
              \(deps.joined(separator: "\n"))
            ],
            path: "\(module.absoluteBasePath.relative(to: projectPath))",
            exclude: [
              \(package.fileExclusions[key]?.map { "\"\($0)\"" }.joined(separator: "\n") ?? "")
            ]
          ),
          """
          targets.append(targetStr)
        }
      }

      return targets.joined(separator: "\n")
    }

    func gen_PRODUCTS(
      packageManager: ModulePackageManager
    ) -> String {
      var result: [String] = []
      packageManager.packages.sorted { $0.name < $1.name }.forEach { package in
        package.modules.keys.sorted { $0.rawValue < $1.rawValue }.forEach { key in
          guard let module = package.modules[key] else { return }
          result.append(".library(name: \"\(module.name)\", targets: [\"\(module.name)\"]),")
        }
      }

      return result.joined(separator: "\n")
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
