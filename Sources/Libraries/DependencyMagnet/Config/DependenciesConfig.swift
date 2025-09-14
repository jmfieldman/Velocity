//
//  DependenciesConfig.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation
import InternalUtilities
import Yams

public class DependencyConfig: Decodable {
    public let url: String

    /// The package version qualifiers, prioritized top-down.
    public let from: String?
    public let range: String?
    public let closedRange: String?
    public let branch: String?
    public let revision: String?
    public let exact: String?

    /// This override is only necessary if the URL's final path component
    /// is not the same name as the package.
    public let packageName: String?

    /// If true, do not pull this dependencies to the local machine.
    /// This is useful to enumerate dependencies for Module Package
    /// generation that cannot be pulled locally.
    public let keepRemote: Bool?

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

    /// Put these dependencies in their own explicit template
    /// (not PackageInclusionTemplate). You can set this to empty
    /// string to prevent it from adding to any template.
    public let templateName: String?

    /// Private constructor to create a dependency for a static project
    /// package config
    fileprivate init(projectPackageConfig: ProjectPackageConfig) {
        self.url = projectPackageConfig.name
        self.packageName = projectPackageConfig.name
        self.libraries = projectPackageConfig.libraries ?? [projectPackageConfig.name]
        self.templateName = projectPackageConfig.templateName

        self.from = nil
        self.range = nil
        self.closedRange = nil
        self.branch = nil
        self.revision = nil
        self.exact = nil
        self.keepRemote = nil
        self.ignoreSha = nil
        self.refreshCursor = nil
    }
}

/// Use this to indicate that certain packages are imported statically
/// by the project.yml (in case you do not want autogen for that package).
/// This allows your modules to import/link with them properly.
public class ProjectPackageConfig: Decodable {
    public let name: String
    public let libraries: [String]?
    public let templateName: String?

    public func dependencyConfig() -> DependencyConfig {
        DependencyConfig(projectPackageConfig: self)
    }
}

public class DependenciesConfig: Decodable {
    public let dependencies: [DependencyConfig]?
    public let projectPackages: [ProjectPackageConfig]?

    public static func from(filePath: String) throws -> DependenciesConfig {
        guard FileManager.default.fileExists(atPath: filePath) else {
            try throwError(.configNotFound, "Config file not found at \(filePath)")
        }

        // Decode config
        let dependenciesConfigData: Data
        let dependenciesConfig: DependenciesConfig
        do {
            dependenciesConfigData = try Data(contentsOf: filePath.prependingCurrentDirectory().fileURL())
            dependenciesConfig = try YAMLDecoder().decode(DependenciesConfig.self, from: dependenciesConfigData)
        } catch {
            try throwError(.configNotDecodable, error.localizedDescription)
        }

        return dependenciesConfig
    }
}
