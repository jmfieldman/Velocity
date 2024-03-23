//
//  DependencyPull.swift
//  Copyright © 2023 Jason Fieldman.
//

import Foundation

private let kBuildDir = ".build"
private let kWorkspaceStateJsonPath = "\(kBuildDir)/workspace-state.json"
private let kPackageResolver = "Package.resolved"

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
    reuseExistingPackageResolvedFile(workspacePath: workspacePath, outputPath: outputPath)
    resolveWorkspacePackage(workspacePath: workspacePath)

    let workspaceState = readWorkspaceState(workspacePath: workspacePath)
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
          vprint(.debug, "Dependency in workspace state: \(name) @ \(version)")
        }
      }

      return state
    } catch {
      throwError(.fileError, "Could read/parse workspace-state.json: \(error.localizedDescription)")
    }
  }
}
