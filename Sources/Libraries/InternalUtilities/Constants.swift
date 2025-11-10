//
//  Constants.swift
//  Copyright © 2025 Jason Fieldman.
//

import Foundation

/// The marker that indicates the root of a logical package. A package
/// may contain multiple sub-modules.
public let kPathPackageYml = "package.yml"

/// The directory that will contain all of the dependency pull/magnet work.
/// This path should be included in .gitignore
public let kPathMagnetWorkspace: String = ".dependency_magnet"

/// The path to the dependencies.yml file
public let kPathDependencyConfig = "dependencies.yml"

/// The path that local dependencies are put under.
/// This path should be included in .gitignore
public let kPathDependencyOutput = "local"

/// Directory for temporary files
public let kCachesDirectory = ".cache"
