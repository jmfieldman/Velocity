//
//  DependencyPull.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation
import InternalUtilities

private let kBuildDir = ".build"
private let kWorkspaceStateFile = "workspace-state.json"
private let kWorkspaceStateJsonPath = "\(kBuildDir)/\(kWorkspaceStateFile)"
private let kPackageResolver = "Package.resolved"
private let kPackagesOutputPath = "Packages"

public class DependencyPull: NSObject {
  public func pull(
    dependencies: [DependencyConfig],
    workspacePath: String,
    outputPath: String
  ) {
    // Validate inputs
    validateNoDuplicates(dependencies)

    // Create output directories
    createDirectory(workspacePath)
    createDirectory(kPackagesOutputPath.prepending(path: outputPath))

    // Setup the workspace and resolve our dependencies
    createWorkspacePackage(workspacePath: workspacePath, dependencies: dependencies)
    reuseExistingPackageResolvedFile(workspacePath: workspacePath, outputPath: outputPath)
    resolveWorkspacePackage(workspacePath: workspacePath)

    // Copy the new dependencies over to the output
    let workspaceState = readWorkspaceState(workspacePath: workspacePath)
    let outputState = readOutputState(outputPath: outputPath)
    let packagesPath = kPackagesOutputPath.prepending(path: outputPath)
    copyDependencies(
      dependencyConfigs: dependencies,
      workspacePath: workspacePath,
      workspaceState: workspaceState,
      outputPath: outputPath,
      outputState: outputState
    )
    replaceRemotePackages(
      dependencyConfigs: dependencies,
      packagesPath: packagesPath,
      workspaceState: workspaceState
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
      try FileManager.default.createDirectory(at: path.prependingCurrentDirectory().directoryURL(), withIntermediateDirectories: true)
    } catch {
      throwError(.fileError, "Could not create directory \(path)")
    }
  }

  /// Verifies that there are no duplicate dependency urls in the
  /// dependencies.yml config
  func validateNoDuplicates(_ dependencies: [DependencyConfig]) {
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
    dependencies: [DependencyConfig]
  ) {
    let packagePath = "Package.swift".prepending(path: workspacePath)

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
    let existingResolvedFile = kPackageResolver.prepending(path: outputPath)
    let targetResolvedFile = kPackageResolver.prepending(path: workspacePath)

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

    vprint(.verbose, "Copied existing \(kPackageResolver) to shadow workspace path")
  }

  /// This performs the actual 'swift package resolve' in the
  /// workspace, pulling the dependencies into the checkout
  /// directory.
  func resolveWorkspacePackage(
    workspacePath: String
  ) {
    vprint(.verbose, "Running 'swift package resolve' on shadow workspace")

    let result = Process.execute(
      command: "swift package resolve",
      workingDirectory: workspacePath.prependingCurrentDirectory().directoryURL(),
      outputStdoutWhileRunning: gVerbosityLevel >= .normal,
      outputStderrWhileRunning: gVerbosityLevel >= .normal
    )

    guard result.exitCode == 0 else {
      throwError(.swiftPackageManager, "'swift package resolve' failed on shadow workspace package in \(workspacePath)")
    }
  }

  /// Replaces all of the remote url-based packages in each dependency
  /// with its local-path version.
  func replaceRemotePackages(
    dependencyConfigs: [DependencyConfig],
    packagesPath: String,
    workspaceState: WorkspaceState
  ) {
    vprint(.debug, "Replacing remote package urls in local packages")

    var needleMap: [String: String] = [:]
    for dependency in workspaceState.object?.dependencies ?? [] {
      // If a dependency is marked 'keepRemote' that we should not add its variants to the needleMap
      guard dependencyConfigs.dependencyConfig(relatedToUrl: dependency.packageRef?.location)?.keepRemote != true else {
        continue
      }

      guard let locationVariants = dependency.packageRef?.location?.locationVariants(), !locationVariants.isEmpty else {
        continue
      }

      guard let subpath = dependency.subpath else {
        continue
      }

      let replacePath = "../\(subpath)"

      for variant in locationVariants {
        needleMap[variant] = replacePath
      }
    }

    for dependency in workspaceState.object?.dependencies ?? [] {
      // If a dependency is marked 'keepRemote' then we should not bother updating its Package.swift file
      guard dependencyConfigs.dependencyConfig(relatedToUrl: dependency.packageRef?.location)?.keepRemote != true else {
        continue
      }

      guard let subpath = dependency.subpath else {
        continue
      }

      let depPath = subpath.prepending(path: packagesPath)
      guard depPath.isDirectory else {
        vprint(.debug, "Skipping dependency \(dependency.displayName) with invalid path \(depPath)")
        continue
      }

      guard let files = try? FileManager.default.contentsOfDirectory(atPath: depPath) else {
        continue
      }

      for depFile in files {
        guard depFile.hasPrefix("Package"), depFile.hasSuffix(".swift") else {
          continue
        }

        replaceOccurrences(
          haystackPath: depFile.prepending(path: depPath),
          needleMap: needleMap
        )
      }
    }
  }

  /// Retains the workspace Package.resolved file in the output path
  func retainPackageResolvedFile(
    workspacePath: String,
    outputPath: String
  ) {
    let outputResolvedFile = kPackageResolver.prepending(path: outputPath)
    let workspaceResolvedFile = kPackageResolver.prepending(path: workspacePath)

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

    vprint(.debug, "Copied shadow workspace \(kPackageResolver) to output path")
  }

  /// Parses the workspace-state.json file in the workspace into a
  /// readable data structure.
  func readWorkspaceState(
    workspacePath: String
  ) -> WorkspaceState {
    let workspaceStateJSONPath = kWorkspaceStateJsonPath.prepending(path: workspacePath)

    do {
      let data = try Data(contentsOf: workspaceStateJSONPath.prependingCurrentDirectory().fileURL())
      let state = try JSONDecoder().decode(WorkspaceState.self, from: data)

      if gVerbosityLevel == .debug {
        for dep in state.object?.dependencies?.sorted() ?? [] {
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
      .prepending(path: kPackagesOutputPath)
      .prepending(path: outputPath)

    do {
      let data = try Data(contentsOf: outputStateJSONPath.prependingCurrentDirectory().fileURL())
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
    let sourceDir = kBuildDir.prepending(path: workspacePath)
    let sourceFile = kWorkspaceStateFile.prepending(path: sourceDir)

    let outputDir = kPackagesOutputPath.prepending(path: outputPath)
    let outputFile = kWorkspaceStateFile.prepending(path: outputDir)

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

    vprint(.debug, "Copied shadow workspace \(kWorkspaceStateFile) to output path")
  }

  /// Copy the dependencies from the workspace to the output
  func copyDependencies(
    dependencyConfigs: [DependencyConfig],
    workspacePath: String,
    workspaceState: WorkspaceState,
    outputPath: String,
    outputState: WorkspaceState
  ) {
    guard let dependencies = workspaceState.object?.dependencies, !dependencies.isEmpty else {
      throwError(.noDependencies, "No dependencies found in workspace state")
    }

    for dependency in dependencies.sorted() {
      guard let subpath = dependency.subpath else {
        vprint(.normal, "Warning: dependency \(dependency.displayName) has no subpath")
        continue
      }

      let dependencyConfig = dependencyConfigs
        .dependencyConfig(relatedToUrl: dependency.packageRef?.location)

      guard dependencyConfig?.keepRemote != true else {
        vprint(.debug, "Respecting keepRemote flag for dependency: \(dependency.displayName)")
        continue
      }

      let sourcePath = subpath
        .prepending(path: "checkouts")
        .prepending(path: kBuildDir)
        .prepending(path: workspacePath)

      let destinationPath = subpath
        .prepending(path: kPackagesOutputPath)
        .prepending(path: outputPath)

      let shouldCopy = shouldCopy(
        dependencyConfig: dependencyConfig,
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

        for _ in 0 ..< 4 {
          // Quiet attempts to remove item first -- squash weird
          // interim issues with DS_Store files created while
          // deleting
          try? fileManager.removeItem(atPath: destinationPath)
        }
        if destinationPath.isDirectory {
          try fileManager.removeItem(atPath: destinationPath)
        }
        try fileManager.copyItem(
          atPath: sourcePath,
          toPath: destinationPath
        )

        // An annoying artifact in some packages is an explicit
        // exclusion for the .git directory; so create a phony
        // directory in the new local versions
        try FileManager.default.createDirectory(
          atPath: ".git".prepending(path: destinationPath),
          withIntermediateDirectories: true
        )

        // Update the creation date of the new local directory
        var values = URLResourceValues()
        values.creationDate = Date()
        var url = destinationPath.directoryURL()
        try url.setResourceValues(values)

      } catch {
        throwError(.fileError, "Could not copy dependency from \(sourcePath) to \(destinationPath): \(error.localizedDescription)")
      }
    }
  }

  /// Determine if a dependency should be copied
  func shouldCopy(
    dependencyConfig: DependencyConfig?,
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

    if !(dependencyConfig?.ignoreSha ?? false) {
      guard let sourceSha = FileManager.default.sha(contentsOf: sourcePath) else {
        throwError(.fileError, "Could not determine shasum of dependency \(workspaceDependency.displayTuple)")
      }

      guard sourceSha == destinationSha else {
        vprint(.debug, "Copy decision: \(workspaceDependency.displayTuple) : YES : shasum mismatch in output path")
        return true
      }
    }

    if let cursor = dependencyConfig?.refreshCursor {
      guard let cursorDate = ISO8601DateFormatter().date(from: cursor) else {
        throwError(.invalidDate, "Invalid date used for refreshCursor for \(workspaceDependency.displayTuple); must be valid UTC ISO8601 format")
      }

      if cursorDate > Date() {
        vprint(.normal, "🚨🚨 Warning 🚨🚨 UTC refreshCursor [\(cursorDate.iso8601())] for \(workspaceDependency.displayTuple) is after current date; the dependency may constantly be re-copied")
      }

      let values = try! destinationPath.directoryURL().resourceValues(forKeys: [.creationDateKey])
      if let creationDate = values.creationDate {
        if creationDate < cursorDate {
          vprint(.debug, "Copy decision: \(workspaceDependency.displayTuple) : YES : UTC creation date [\(creationDate.iso8601())] is earlier refreshCursor [\(cursorDate.iso8601())]")
          return true
        }
      }
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
  public func fileManager(
    _ fileManager: FileManager,
    shouldCopyItemAtPath srcPath: String,
    toPath dstPath: String
  ) -> Bool {
    !(srcPath.hasSuffix(".git") || srcPath.hasSuffix("DS_Store"))
  }
}

extension DependencyPull {
  /// Replace each key in the needle map with its value, in the file
  /// at haystackPath.
  func replaceOccurrences(
    haystackPath: String,
    needleMap: [String: String]
  ) {
    guard haystackPath.isFile else {
      return
    }

    let fileString: String
    do {
      fileString = try String(contentsOfFile: haystackPath)
    } catch {
      throwError(.fileError, "Could not read file \(haystackPath)")
    }

    let lines = fileString.replacePackageUrls(needleMap: needleMap)

    do {
      try lines.write(toFile: haystackPath, atomically: true, encoding: .utf8)
    } catch {
      throwError(.fileError, "Could not write to file \(haystackPath)")
    }
  }
}
