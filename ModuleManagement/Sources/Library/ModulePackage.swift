//
//  ModulePackage.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation
import Yams

private let yamlDecoder = YAMLDecoder()

public final class ModulePackage {
  public let name: String
  private let config: ModulePackageConfig

  /// Absolute path the the package.yml for this ModulePackage
  private let filePath: String

  /// The absolute base path of `filePath` with trailing slash
  private let absoluteBasePath: String

  /// The base path within the top-level project scope
  private let projectBasePath: String

  /// Modules contained in this package
  public private(set) lazy var modules: [ModuleType: Module] = self.scanModules()

  public private(set) lazy var settingsOverrides: [ModuleType: [String: String]] = self.config.settingsOverrides?.mapKeys { ModuleType(rawValue: $0) } ?? [:]

  public private(set) lazy var fileExclusions: [ModuleType: [String]] = self.config.fileExclusions?.mapKeys { ModuleType(rawValue: $0) } ?? [:]

  public init?(
    packageFilePath: String,
    absoluteProjectPath: String
  ) {
    guard var fileContents = try? String(contentsOfFile: packageFilePath, encoding: .utf8) else {
      return nil
    }

    // An empty package.yml should be allowed, and considered an empty dictionary.
    if fileContents.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
      fileContents = "{}"
    }

    guard let config = try? yamlDecoder.decode(ModulePackageConfig.self, from: fileContents, userInfo: [:]) else {
      return nil
    }

    let absoluteBasePath = (packageFilePath as NSString).deletingLastPathComponent

    self.config = config
    self.filePath = packageFilePath
    self.absoluteBasePath = packageFilePath.basePath.appendingMissingSlash()
    self.projectBasePath = absoluteBasePath.relative(to: absoluteProjectPath).appendingMissingSlash()
    self.name = absoluteBasePath.lastPathComponent
  }

  // MARK: Private Helpers

  private func moduleNameFor(type: ModuleType) -> String {
    type.directory(for: name)
  }

  private func scanModules() -> [ModuleType: Module] {
    guard config.disable.flatMap({ !$0 }) ?? true else { return [:] }

    return Dictionary(uniqueKeysWithValues: ModuleType.allCases.compactMap { type in
      let moduleDirectory = "\(self.absoluteBasePath)\(type.directory(for: self.name))"
      if FileManager.default.directoryExists(atPath: moduleDirectory) {
        guard FileManager.default.directory(at: moduleDirectory, contains: { $0.hasSuffix(".swift") }) else {
          return nil
        }

        return (type, Module(
          name: self.moduleNameFor(type: type),
          type: type,
          absoluteBasePath: "\(moduleDirectory)/",
          projectBasePath: "\(self.projectBasePath)\(type.directory(for: self.name))/"
        ))
      }

      return nil
    })
  }
}
