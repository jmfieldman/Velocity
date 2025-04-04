//
//  GenerateImports.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities
import ModuleManagementLib
import ProjectSpec
import Yams

public struct GenerateImportsOptions {
    public let searchPath: String
    public let projectPath: String?
    public let packageFilename: String

    public init(
        searchPath: String = ".",
        projectPath: String? = nil,
        packageFilename: String = "package.yml"
    ) {
        self.searchPath = searchPath
        self.projectPath = projectPath
        self.packageFilename = packageFilename
    }
}

public enum GenerateImports {
    public static func execute(with options: GenerateImportsOptions) throws {
        let fullSearchPath = options.searchPath.prependingCurrentDirectory()
        let projectPath = options.projectPath?.prependingCurrentDirectory() ?? FileManager.default.currentDirectoryPath

        // Verify path exists
        guard FileManager.default.directoryExists(atPath: fullSearchPath) else {
            try throwError(.pathNotFound, "Directory not found at search path: \(fullSearchPath)")
        }

        guard FileManager.default.directoryExists(atPath: projectPath) else {
            try throwError(.pathNotFound, "Directory not found at project path: \(projectPath)")
        }

        let packages = ModulePackageManager.packages(
            named: options.packageFilename,
            root: fullSearchPath,
            absoluteProjectPath: projectPath
        )

        vprint(.normal, "Regenerate imports for \(packages.count) package\(packages.count == 1 ? "" : "s")", "🔧")

        packages.sorted { $0.name < $1.name }.forEach { package in
            package.modules.values.sorted { $0.name < $1.name }.forEach { module in
                vprint(.debug, "Regenerate imports for \(module.name)", "🔧")
                module.regenerateImportsFile(ignoreFilenames: [])
            }
        }
    }
}
