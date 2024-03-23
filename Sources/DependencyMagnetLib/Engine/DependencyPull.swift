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
  ) async {
    createDirectory(workspacePath)
    createDirectory(outputPath)

    
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
}
