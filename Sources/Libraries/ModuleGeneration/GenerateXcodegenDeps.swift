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
    public let dependenciesConfig: String
    public let dependencyOutputPath: String?

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

        var packages: [String: PackageEnc] = [:]
        try dependencies.sorted { $0.inferredPackageName < $1.inferredPackageName }.forEach { dependency in
            var packageEnc = PackageEnc()
            if let depOutputPath = options.dependencyOutputPath, dependency.keepRemote != true {
                packageEnc.path = "\(depOutputPath)/Packages/\(dependency.inferredPackageName)"
            } else {
                packageEnc.url = dependency.url

                if let from = dependency.from {
                    packageEnc.from = from
                } else if let branch = dependency.branch {
                    packageEnc.branch = branch
                } else if let revision = dependency.revision {
                    packageEnc.revision = revision
                } else if let exact = dependency.exact {
                    packageEnc.exactVersion = exact
                } else {
                    try throwError(.noDependencyQualifier, "xcodegen does not support range qualifiers for package versions, use [from, branch, revision or exact] in dependencies.yml")
                }
            }

            packages[dependency.inferredPackageName] = packageEnc
        }

        let packagesEnc = PackagesEnc(packages: packages)
        let encoder = YAMLEncoder()
        encoder.options = Emitter.Options(sortKeys: true, sequenceStyle: .block, mappingStyle: .block)
        let encodedString = try encoder.encode(packagesEnc)

        try! encodedString.removingEmptyYml().write(
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

// MARK: Encodable Objects for YAML Output

private struct PackagesEnc: Encodable {
    var packages: [String: PackageEnc]
}

private struct PackageEnc: Encodable {
    var path: String?
    var url: String?
    var from: String?
    var branch: String?
    var revision: String?
    var exactVersion: String?
}
