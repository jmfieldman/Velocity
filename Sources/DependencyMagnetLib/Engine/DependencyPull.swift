//
//  DependencyPull.swift
//  Copyright © 2023 Jason Fieldman.
//

import Foundation

public class DependencyPull {
  public init() {}

  public func pull(
    dependencies: [Dependency],
    workspacePath: String,
    outputPath: String
  ) {
    validateNoDuplicates(dependencies)
    createDirectory(workspacePath)
    createDirectory(outputPath)
    createWorkspacePackage(workspacePath: workspacePath, dependencies: dependencies)
  }
}

extension DependencyPull {
  func createDirectory(_ path: String) {
    do {
      try FileManager.default.createDirectory(at: path.prependingCurrentDirectoryPath().asDirectoryURL(), withIntermediateDirectories: true)
    } catch {
      throwError(.fileError, "Could not create directory \(path)")
    }
  }

  func validateNoDuplicates(_ dependencies: [Dependency]) {
    var urls: Set<String> = []
    for dependency in dependencies {
      if urls.contains(dependency.url) {
        throwError(.duplicateDependencies, "Duplicate dependency found: \(dependency.url)")
      }
      urls.insert(dependency.url)
    }
  }

  func createWorkspacePackage(
    workspacePath: String,
    dependencies: [Dependency]
  ) {
    let packagePath = "Package.swift".prepending(directoryPath: workspacePath)

    let dependencyArray = dependencies.map { "    \($0.packageString)," }.joined(separator: "\n")

    let packageContents = """
    // swift-tools-version:5.8
    import PackageDescription
    let package = Package(
      name: "package",
      products: [],
      dependencies: [
    {dependencies}
      ],
      targets: []
    )
    """.replacingOccurrences(of: "{dependencies}", with: dependencyArray)

    do {
      try packageContents.write(toFile: packagePath, atomically: true, encoding: .utf8)
    } catch {
      throwError(.fileError, "Could not write to package file [\(packagePath)]: \(error.localizedDescription)")
    }
  }
}
