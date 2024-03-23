//
//  DependencyPull.swift
//  Copyright © 2023 Jason Fieldman.
//

import Foundation

private let kBuildDir = ".build"
private let kWorkspaceStateFile = "workspace-state.json"
private let kWorkspaceStateJsonPath = "\(kBuildDir)/\(kWorkspaceStateFile)"
private let kPackageResolver = "Package.resolved"
private let kPackagesOutputPath = "Packages"

public class DependencyPull {
  public init() {}

  public func pull(
    dependencies: [Dependency],
    workspacePath: String,
    outputPath: String
  ) {
    validateNoDuplicates(dependencies)
    createDirectory(workspacePath)
    createDirectory(kPackagesOutputPath.prepending(directoryPath: outputPath))
    createWorkspacePackage(workspacePath: workspacePath, dependencies: dependencies)
    reuseExistingPackageResolvedFile(workspacePath: workspacePath, outputPath: outputPath)
    resolveWorkspacePackage(workspacePath: workspacePath)
    retainPackageResolvedFile(workspacePath: workspacePath, outputPath: outputPath)
    let workspaceState = readWorkspaceState(workspacePath: workspacePath)
    retainWorkspaceStateFile(workspacePath: workspacePath, outputPath: outputPath)
  }
}

extension DependencyPull {
  /// This helper function ensures that a directory exists at the specified
  /// path.
  func createDirectory(_ path: String) {
    do {
      try FileManager.default.createDirectory(at: path.prependingCurrentDirectoryPath().asDirectoryURL(), withIntermediateDirectories: true)
    } catch {
      throwError(.fileError, "Could not create directory \(path)")
    }
  }

  /// Verifies that there are no duplicate dependency urls in the
  /// dependencies.yml config
  func validateNoDuplicates(_ dependencies: [Dependency]) {
    var urls: Set<String> = []
    for dependency in dependencies {
      if urls.contains(dependency.url) {
        throwError(.duplicateDependencies, "Duplicate dependency found: \(dependency.url)")
      }
      urls.insert(dependency.url)
    }
  }

  /// Creates the Package.swift file in the workspace; this package
  /// references all of the dependencies so that they can be pulled
  /// into the workspace checkout directory.
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

  /// This pulls the Package.resolved file from the output path
  /// back into the workspace path, so that the resolved versions
  /// can be reused if possible.
  func reuseExistingPackageResolvedFile(
    workspacePath: String,
    outputPath: String
  ) {
    let existingResolvedFile = kPackageResolver.prepending(directoryPath: outputPath)
    let targetResolvedFile = kPackageResolver.prepending(directoryPath: workspacePath)

    guard existingResolvedFile.isFile else {
      vprint(.verbose, "No existing \(kPackageResolver) to reuse in output path")
      return
    }

    do {
      if targetResolvedFile.isFile {
        try FileManager.default.removeItem(atPath: targetResolvedFile)
      }
      try FileManager.default.copyItem(
        atPath: existingResolvedFile,
        toPath: targetResolvedFile
      )
    } catch {
      throwError(.fileError, "Could not copy \(kPackageResolver) from \(outputPath) to \(workspacePath): \(error.localizedDescription)")
    }

    vprint(.verbose, "Copied existing \(kPackageResolver) to workspace path")
  }

  /// This performs the actual 'swift package resolve' in the
  /// workspace, pulling the dependencies into the checkout
  /// directory.
  func resolveWorkspacePackage(
    workspacePath: String
  ) {
    vprint(.verbose, "Running 'swift package resolve' on workspace")

    let result = Process.execute(
      command: "swift package resolve",
      workingDirectory: workspacePath.prependingCurrentDirectoryPath().asDirectoryURL(),
      outputStdoutWhileRunning: gVerbosityLevel >= .normal,
      outputStderrWhileRunning: gVerbosityLevel >= .normal
    )

    guard result.exitCode == 0 else {
      throwError(.swiftPackageManager, "'swift package resolve' failed on workspace package in \(workspacePath)")
    }
  }

  /// Retains the workspace Package.resolved file in the output path
  func retainPackageResolvedFile(
    workspacePath: String,
    outputPath: String
  ) {
    let outputResolvedFile = kPackageResolver.prepending(directoryPath: outputPath)
    let workspaceResolvedFile = kPackageResolver.prepending(directoryPath: workspacePath)

    guard workspaceResolvedFile.isFile else {
      vprint(.verbose, "No \(kPackageResolver) in workspace path")
      return
    }

    do {
      if outputResolvedFile.isFile {
        try FileManager.default.removeItem(atPath: outputResolvedFile)
      }
      try FileManager.default.copyItem(
        atPath: workspaceResolvedFile,
        toPath: outputResolvedFile
      )
    } catch {
      throwError(.fileError, "Could not copy \(kPackageResolver) from \(workspacePath) to \(outputPath): \(error.localizedDescription)")
    }

    vprint(.verbose, "Copied workspace \(kPackageResolver) to output path")
  }

  /// Parses the workspace-state.json file in the workspace into a
  /// readable data structure.
  func readWorkspaceState(
    workspacePath: String
  ) -> WorkspaceState {
    let workspaceStateJSONPath = kWorkspaceStateJsonPath.prepending(directoryPath: workspacePath)

    do {
      let data = try Data(contentsOf: workspaceStateJSONPath.prependingCurrentDirectoryPath().asFileURL())
      let state = try JSONDecoder().decode(WorkspaceState.self, from: data)

      if gVerbosityLevel == .debug {
        for dep in state.object?.dependencies ?? [] {
          let name = dep.packageRef?.name ?? dep.packageRef?.identity ?? "??"
          let version = dep.state?.checkoutState?.version ?? dep.state?.checkoutState?.revision ?? "??"
          vprint(.debug, "Dependency in workspace: [\(name) @ \(version)]")
        }
      }

      return state
    } catch {
      throwError(.fileError, "Could read/parse workspace-state.json: \(error.localizedDescription)")
    }
  }

  /// Retains the workspace-state.json file in the output path after
  /// files have been successfully copied over
  func retainWorkspaceStateFile(
    workspacePath: String,
    outputPath: String
  ) {
    let sourceDir = kBuildDir.prepending(directoryPath: workspacePath)
    let sourceFile = kWorkspaceStateFile.prepending(directoryPath: sourceDir)

    let outputDir = kPackagesOutputPath.prepending(directoryPath: outputPath)
    let outputFile = kWorkspaceStateFile.prepending(directoryPath: outputDir)

    guard sourceFile.isFile else {
      vprint(.verbose, "No \(kWorkspaceStateFile) in workspace path")
      return
    }

    do {
      if outputFile.isFile {
        try FileManager.default.removeItem(atPath: outputFile)
      }
      try FileManager.default.copyItem(
        atPath: sourceFile,
        toPath: outputFile
      )
    } catch {
      throwError(.fileError, "Could not copy \(kWorkspaceStateFile) from \(sourceDir) to \(outputDir): \(error.localizedDescription)")
    }

    vprint(.verbose, "Copied workspace \(kWorkspaceStateFile) to output path")
  }
}
