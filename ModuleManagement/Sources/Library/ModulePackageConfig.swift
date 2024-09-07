//
//  ModulePackageConfig.swift
//  Copyright © 2021 Jason Fieldman.
//

import Foundation

/// Represents the Codable format of package.yml files.
/// All fields are optional. It is valid/expected that package.yml files are
/// normally empty.
public class ModulePackageConfig: Codable {
  /// Optional description that can be used in debug/tooling output; not required
  public let description: String?

  /// If true, the module will be completely disabled and not included into any
  /// production project output.
  public let disable: Bool?

  /// If true, will disable test modules from being produced. Useful as a safety
  /// valve to turn off faulty tests while they can be repaired.
  public let disableTests: Bool?

  /// Allows subdirectory override. The key is the Module type (main, impl, etc).
  public let directoryOverrides: [String: String]?

  /// Any special build settings for modules in the package, keyed by module type.
  public let settingsOverrides: [String: [String: String]]?

  /// A list of files to exclude, keyed by module type.
  public let fileExclusions: [String: [String]]?
}
