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

public class DependencyPull: NSObject {
  public func pull(
    dependencies: [Dependency],
    workspacePath: String,
    outputPath: String
  ) {
    // Validate inputs
    validateNoDuplicates(dependencies)

    // Create output directories
    createDirectory(workspacePath)
    createDirectory(kPackagesOutputPath.prepending(directoryPath: outputPath))

    // Setup the workspace and resolve our dependencies
    createWorkspacePackage(workspacePath: workspacePath, dependencies: dependencies)
    reuseExistingPackageResolvedFile(workspacePath: workspacePath, outputPath: outputPath)
    resolveWorkspacePackage(workspacePath: workspacePath)

    // Copy the new dependencies over to the output
    let workspaceState = readWorkspaceState(workspacePath: workspacePath)
    let outputState = readOutputState(outputPath: outputPath)
    copyDependencies(
      workspacePath: workspacePath,
      workspaceState: workspaceState,
      outputPath: outputPath,
      outputState: outputState
    )

    // Keep the generated state files
    retainPackageResolvedFile(workspacePath: workspacePath, outputPath: outputPath)
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

    vprint(.debug, "Copied workspace \(kPackageResolver) to output path")
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
          vprint(.debug, "Dependency in workspace: \(dep.displayTuple)")
        }
      }

      return state
    } catch {
      throwError(.fileError, "Could read/parse workspace-state.json: \(error.localizedDescription)")
    }
  }

  /// Parses the workspace-state.json file in the output into a
  /// readable data structure.
  func readOutputState(
    outputPath: String
  ) -> WorkspaceState {
    let outputStateJSONPath = kWorkspaceStateFile
      .prepending(directoryPath: kPackagesOutputPath)
      .prepending(directoryPath: outputPath)

    do {
      let data = try Data(contentsOf: outputStateJSONPath.prependingCurrentDirectoryPath().asFileURL())
      return try JSONDecoder().decode(WorkspaceState.self, from: data)
    } catch {
      vprint(.verbose, "No \(kWorkspaceStateFile) in output path")
      return WorkspaceState(object: WorkspaceStateObject(dependencies: []))
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

    vprint(.debug, "Copied workspace \(kWorkspaceStateFile) to output path")
  }

  /// Copy the dependencies from the workspace to the output
  func copyDependencies(
    workspacePath: String,
    workspaceState: WorkspaceState,
    outputPath: String,
    outputState: WorkspaceState
  ) {
    guard let dependencies = workspaceState.object?.dependencies, !dependencies.isEmpty else {
      throwError(.noDependencies, "No dependencies found in workspace state")
    }

    for dependency in dependencies {
      guard let subpath = dependency.subpath else {
        vprint(.normal, "Warning: dependency \(dependency.displayName) has no subpath")
        continue
      }

      let sourcePath = subpath
        .prepending(directoryPath: "checkouts")
        .prepending(directoryPath: kBuildDir)
        .prepending(directoryPath: workspacePath)

      let destinationPath = subpath
        .prepending(directoryPath: kPackagesOutputPath)
        .prepending(directoryPath: outputPath)

      let shouldCopy = shouldCopy(
        workspaceDependency: dependency,
        outputDependency: outputState.dependency(withIdentifier: dependency.packageRef?.identity),
        sourcePath: sourcePath,
        destinationPath: destinationPath
      )

      guard shouldCopy else {
        continue
      }

      // Remove the existing output and copy it ou
      let fileManager = FileManager()
      fileManager.delegate = self
      do {
        vprint(.normal, "Importing \(dependency.displayTuple)")
        if destinationPath.isDirectory {
          try fileManager.removeItem(atPath: destinationPath)
        }
        try fileManager.copyItem(
          atPath: sourcePath,
          toPath: destinationPath
        )
      } catch {
        throwError(.fileError, "Could not copy dependency from \(sourcePath) to \(destinationPath): \(error.localizedDescription)")
      }
    }
  }

  /// Determine if a dependency should be copied
  func shouldCopy(
    workspaceDependency: WorkspaceStateDependency,
    outputDependency: WorkspaceStateDependency?,
    sourcePath: String,
    destinationPath: String
  ) -> Bool {
    guard destinationPath.isDirectory else {
      vprint(.debug, "Copy decision: \(workspaceDependency.displayTuple) : YES : does not exist in the output path")
      return true
    }

    guard let outputDependency else {
      vprint(.debug, "Copy decision: \(workspaceDependency.displayTuple) : YES : not tracked in output workspace-state.json")
      return true
    }

    guard workspaceDependency.versionForEquality == outputDependency.versionForEquality else {
      vprint(.debug, "Copy decision: \(workspaceDependency.displayTuple) : YES : revision mismatch \(workspaceDependency.versionForEquality) vs. \(outputDependency.versionForEquality)")
      return true
    }

    guard let destinationSha = FileManager.default.sha(contentsOf: destinationPath) else {
      vprint(.debug, "Copy decision: \(workspaceDependency.displayTuple) : YES : could not verify shasum")
      return true
    }

    guard let sourceSha = FileManager.default.sha(contentsOf: sourcePath) else {
      throwError(.fileError, "Could not determine shasum of dependency \(workspaceDependency.displayTuple)")
    }

    guard sourceSha == destinationSha else {
      vprint(.debug, "Copy decision: \(workspaceDependency.displayTuple) : YES : shasum mismatch in output path")
      return true
    }

    vprint(.debug, "Copy decision: \(workspaceDependency.displayTuple) : NO : found existing match in output")
    return false
  }
}

extension DependencyPull: FileManagerDelegate {
  /// We should ignore copy errors involving .DS_Store
  public func fileManager(
    _ fileManager: FileManager,
    shouldProceedAfterError error: Error,
    copyingItemAtPath srcPath: String,
    toPath dstPath: String
  ) -> Bool {
    srcPath.hasSuffix("DS_Store")
  }

  /// Do not copy .git files
  public func fileManager(_ fileManager: FileManager, shouldCopyItemAtPath srcPath: String, toPath dstPath: String) -> Bool {
    !(srcPath.hasSuffix(".git") || srcPath.hasSuffix("DS_Store"))
  }
}
