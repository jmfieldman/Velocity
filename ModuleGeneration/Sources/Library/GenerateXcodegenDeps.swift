//
//  GenerateXcodegenDeps.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities
import ModuleManagementLib
import ProjectSpec
import Yams

public struct GenerateXcodegenDepsOptions {
    public let outputFilename: String
    public var dependenciesConfig: String
    public var dependencyOutputPath: String?

    public init(
        outputFilename: String,
        dependenciesConfig: String,
        dependencyOutputPath: String? = nil
    ) {
        self.outputFilename = outputFilename
        self.dependenciesConfig = dependenciesConfig
        self.dependencyOutputPath = dependencyOutputPath
    }
}

public enum GenerateXcodegenDeps {
    public static func execute(with options: GenerateXcodegenDepsOptions) throws {
        // Verify dependencies file exists
        guard FileManager.default.fileExists(atPath: options.dependenciesConfig) else {
            try throwError(.pathNotFound, "Dependencies file not found at path: \(options.dependenciesConfig)")
        }

        vprint(.normal, "Generating \(options.outputFilename)", "🔧")

        if options.dependencyOutputPath == nil {
            vprint(.normal, "No dependency magent output path provided, all packages will use remote repo")
        }

        let dependenciesConfig = try DependenciesConfig.from(filePath: options.dependenciesConfig)
        guard let dependencies = dependenciesConfig.dependencies, dependencies.count > 0 else {
            vprint(.normal, "No dependencies found in \(dependenciesConfig)")
            return
        }

        var packages: [String: [String: Any]] = [:]
        try dependencies.sorted { $0.inferredPackageName < $1.inferredPackageName }.forEach { dependency in
            var depDict: [String: Any] = [:]
            if let depOutputPath = options.dependencyOutputPath, dependency.keepRemote != true {
                depDict["path"] = "\(depOutputPath)/Packages/\(dependency.inferredPackageName)"
            } else {
                depDict["url"] = dependency.url

                if let from = dependency.from {
                    depDict["from"] = from
                } else if let branch = dependency.branch {
                    depDict["branch"] = branch
                } else if let revision = dependency.revision {
                    depDict["revision"] = revision
                } else if let exact = dependency.exact {
                    depDict["exactVersion"] = exact
                } else {
                    try throwError(.noDependencyQualifier, "xcodegen does not support range qualifiers for package versions, use [from, branch, revision or exact] in dependencies.yml")
                }
            }

            packages[dependency.inferredPackageName] = depDict
        }

        try! (try! Yams.dump(
            object: ["packages": packages],
            sortKeys: true
        )).removingEmptyYml().write(
            toFile: options.outputFilename,
            atomically: true,
            encoding: .utf8
        )
    }
}

private extension String {
    func removingEmptyYml() -> String {
        components(separatedBy: .newlines)
            .filter { !($0.contains(": null") || $0.contains(": []") || $0.contains(": {}")) }
            .joined(separator: "\n")
    }
}
