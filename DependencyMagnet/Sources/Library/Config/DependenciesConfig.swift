//
//  DependenciesConfig.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation

public struct DependencyConfig: Decodable {
  public let url: String

  /// The package version qualifiers, prioritized top-down.
  public let from: String?
  public let range: String?
  public let closedRange: String?
  public let branch: String?
  public let revision: String?
  public let exact: String?

  /// Enumerate the libraries that this package provides. This is
  /// used during automatic module generation to understand what
  /// external dependencies are invoked based on import statements.
  public let libraries: [String]?

  /// If this is true, then we will ignore the SHA hashes for this
  /// dependency when determining if a new copy needs to be updated
  /// from the shadow workspace. This is useful if there are local
  /// changes to the dependency from some other kind of patching tool.
  public let ignoreSha: Bool?

  /// The UTC timestamp that the local dependency must be at least
  /// updated since. If the local dependency was last updated before
  /// this cursor, then it will be forced to take a copy from the
  /// shadow workspace. Useful if some kind of patching tool requires
  /// a fresh state of the dependency even if it's the same release
  /// version.
  public let refreshCursor: String?
}

public struct DependenciesConfig: Decodable {
  public let dependencies: [DependencyConfig]?
}
