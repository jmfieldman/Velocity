//
//  GenerateXcodegenDeps.swift
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
  final class GenerateXcodegenDeps: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
      abstract: "Generate Xcodegen project-dependencies.yml from dependencies.yml file"
    )

    @OptionGroup var commonOptions: CommonOptions

    @Option(help: "Override the generated yml filename")
    public var outputFilename: String = "project-dependencies.yml"

    @Option(help: "Path to the dependencies.yml file that lists the dependencies for this project")
    public var dependenciesConfig: String = "Dependencies/dependencies.yml"

    @Option(help: "The output path of the dependency_magnet command used to create local packages, without the Package directory suffix. If not provided then no local packages will be used. If using the default setup this should be \"Dependencies\".")
    public var dependencyOutputPath: String?

    func run() async throws {
      setVerbosity(commonOptions.verbosity)

      // Verify dependencies file exists
      guard FileManager.default.fileExists(atPath: dependenciesConfig) else {
        throwError(.pathNotFound, "Dependencies file not found at path: \(dependenciesConfig)")
      }

      vprint(.normal, "Generating \(outputFilename)", "🔧")

      if dependencyOutputPath == nil {
        vprint(.normal, "No dependency magent output path provided, all packages will use remote repo")
      }

      let dependenciesConfig = DependenciesConfig.from(filePath: dependenciesConfig)
      guard let dependencies = dependenciesConfig.dependencies, dependencies.count > 0 else {
        vprint(.normal, "No dependencies found in \(dependenciesConfig)")
        return
      }

      var packages: [String: [String: Any]] = [:]
      dependencies.sorted { $0.inferredPackageName < $1.inferredPackageName }.forEach { dependency in
        var depDict: [String: Any] = [:]
        if let depOutputPath = dependencyOutputPath, dependency.keepRemote != true {
          depDict["path"] = "\(depOutputPath)/Packages/\(dependency.inferredPackageName)"
        } else {
          depDict["url"] = dependency.url

          if let from = dependency.from {
            depDict["from"] = from
          } else if let branch = dependency.branch {
            depDict["branch"] = branch
          } else if let revision = dependency.revision {
            depDict["revision"] = revision
          } else if let exact = dependency.exact {
            depDict["exactVersion"] = exact
          } else {
            throwError(.noDependencyQualifier, "xcodegen does not support range qualifiers for package versions, use [from, branch, revision or exact] in dependencies.yml")
          }
        }

        packages[dependency.inferredPackageName] = depDict
      }

      try! (try! Yams.dump(
        object: ["packages": packages],
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
