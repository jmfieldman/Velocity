//
//  Module.swift
//  Copyright © 2022 Jason Fieldman.
//

import Foundation
import InternalUtilities
import ProjectSpec
import Yams

private let kImportsYml = "imports.yml"
private let importsDecoder = YAMLDecoder()

public final class Module {
  public let name: String
  public let type: ModuleType

  /// The absolute base path of the module
  private let absoluteBasePath: String

  /// The base path within the top-level project scope
  private let projectBasePath: String

  private lazy var importsFilePath = self.absoluteBasePath + kImportsYml

  init(name: String, type: ModuleType, absoluteBasePath: String, projectBasePath: String) {
    self.name = name
    self.type = type
    self.absoluteBasePath = absoluteBasePath
    self.projectBasePath = projectBasePath
  }

  public private(set) lazy var importedModules: [String] = self.regenerateImportsIfNecessary()

  private func regenerateImportsIfNecessary() -> [String] {
    (try? String(contentsOfFile: importsFilePath, encoding: .utf8)).flatMap {
      try? importsDecoder.decode([String].self, from: $0)
    } ?? (regenerateImportsFile(ignoreFilenames: []) ?? [])
  }

  @discardableResult public func regenerateImportsFile(
    ignoreFilenames: Set<String>
  ) -> [String]? {
    guard let imports = SwiftImportDetector.execute(
      path: absoluteBasePath,
      deepSearch: true,
      ignoreFilenames: ignoreFilenames
    )?.sorted() else {
      return nil
    }

    // Delete stray imports.yml if there are no imports in the module
    guard imports.count > 0 else {
      try? FileManager.default.removeItem(atPath: importsFilePath)
      return []
    }

    if var node = try? Yams.Node(imports) {
      node.sequence?.style = .block
      if let string = try? Yams.serialize(node: node) {
        try? string.write(toFile: importsFilePath, atomically: true, encoding: .utf8)
      }
    }

    return imports
  }

  public private(set) lazy var target: ProjectSpec.Target = generateTarget()

  private func generateTarget() -> ProjectSpec.Target {
    ProjectSpec.Target(
      name: name,
      type: .framework,
      platform: .auto,
      sources: [
        TargetSource(
          path: projectBasePath.removingSlash(),
          excludes: [kImportsYml]
        ),
      ],
      dependencies: importedModules.map {
        Dependency(
          type: .framework,
          reference: $0
        )
      }
    )
  }
}
