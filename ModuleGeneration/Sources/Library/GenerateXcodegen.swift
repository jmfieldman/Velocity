//
//  GenerateXcodegen.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities
import ModuleManagementLib
import ProjectSpec
import Yams

let kDefaultExclusionList: [String] = [
    "imports.yml",
    "inject.yml",
    "README.md",
    "LICENSE",
]

public struct GenerateXcodegenOptions {
    public let rootPath: String
    public let regenImports: Bool
    public let outputFilename: String
    public let platforms: String
    public let dependenciesConfig: String
    public let packageFileName: String

    public init(
        rootPath: String,
        regenImports: Bool = false,
        outputFilename: String = "project-modules.yml",
        platforms: String = "iOS",
        dependenciesConfig: String = "Dependencies/dependencies.yml",
        packageFileName: String = "package.yml"
    ) {
        self.regenImports = regenImports
        self.rootPath = rootPath
        self.outputFilename = outputFilename
        self.platforms = platforms
        self.dependenciesConfig = dependenciesConfig
        self.packageFileName = packageFileName
    }
}

public enum GenerateXcodegen {
    public static func execute(with options: GenerateXcodegenOptions) throws {
        let absoluteModuleBasePath = options.rootPath.prependingCurrentDirectory()
        let absoluteProjectPath = FileManager.default.currentDirectoryPath

        // Verify root path exists
        guard FileManager.default.directoryExists(atPath: absoluteModuleBasePath) else {
            try throwError(.pathNotFound, "Module directory not found at path: \(options.rootPath)")
        }

        let supportedDestinations: [ProjectSpec.SupportedDestination] = try options.platforms
            .components(separatedBy: ",")
            .map {
                guard let dest = ProjectSpec.SupportedDestination(rawValue: $0) else {
                    try throwError(.invalidArgument, "\($0) is not a valid platform -- options are (iOS, tvOS, watchOS, visionOS, macOS, macCatalyst)")
                }
                return dest
            }

        let packages = ModulePackageManager.packages(
            named: options.packageFileName,
            root: options.rootPath,
            absoluteProjectPath: absoluteProjectPath
        )

        let dependenciesConfig = try DependenciesConfig.from(filePath: options.dependenciesConfig)
        var dependencyLookup: [String: DependencyConfig] = [:]
        dependenciesConfig.dependencies?.forEach { pkg in
            if let libs = pkg.libraries, libs.count > 0 {
                libs.forEach { dependencyLookup[$0] = pkg }
            } else {
                dependencyLookup[pkg.inferredPackageName] = pkg
            }
        }
        if dependencyLookup.count == 0 {
            vprint(.verbose, "No external dependencies were detected at \(dependenciesConfig)")
        }

        guard packages.count > 0 else {
            vprint(.normal, "No packages found at root path: \(options.rootPath)")
            return
        }

        if options.regenImports {
            vprint(.normal, "Regenerate imports for \(packages.count) package\(packages.count == 1 ? "" : "s")", "🔧")
            packages.sorted { $0.name < $1.name }.forEach { package in
                package.modules.values.sorted { $0.name < $1.name }.forEach { module in
                    vprint(.debug, "Regenerate imports for \(module.name)", "🔧")
                    module.regenerateImportsFile(ignoreFilenames: [])
                }
            }
        }

        // Load our internal module set
        let internalModuleSet = Set(packages.flatMap { package in
            package.modules.values.map(\.name)
        })

        vprint(.normal, "Generating \(options.outputFilename)", "🔧")

        var targets: [String: [String: Any]] = [:]
        packages.sorted { $0.name < $1.name }.forEach { package in
            package.modules.keys.sorted { $0.rawValue < $1.rawValue }.forEach { moduleType in
                let module = package.modules[moduleType]!

                // Determine dependencies

                // Process the imported modules to generate internal and external dependencies
                let (internalDependencies, externalRefs) = module.importedModules.sorted().reduce(into: ([ProjectSpec.Dependency](), [String: [String]]())) { result, depName in
                    if internalModuleSet.contains(depName) {
                        // Append internal dependencies
                        result.0.append(.init(type: .target, reference: depName))
                    } else if let depConfig = dependencyLookup[depName] {
                        // Build external references
                        result.1[depConfig.inferredPackageName, default: []].append(depName)
                    }
                }

                // Convert external references into dependencies and log them
                let externalDependencies = externalRefs
                    .sorted(by: { $0.key < $1.key })
                    .map { ref -> ProjectSpec.Dependency in
                        .init(type: .package(products: ref.value), reference: ref.key)
                    }

                // Combine internal and external dependencies
                let dependencies = internalDependencies + externalDependencies

                // Determine source exclusions

                let exclusions = (kDefaultExclusionList + (package.fileExclusions[moduleType] ?? []))
                    .filter { exclusion in
                        FileManager.default.fileExists(atPath: "\(module.projectBasePath)/\(exclusion)")
                    }

                // Generate Target object

                let target = ProjectSpec.Target(
                    name: module.name,
                    type: module.type == .tests ? .unitTestBundle : .framework,
                    platform: .auto,
                    supportedDestinations: supportedDestinations,
                    sources: [.init(
                        path: module.projectBasePath,
                        excludes: exclusions
                    )],
                    dependencies: dependencies
                )

                targets[module.name] = target.toJSONValue() as? [String: Any]
            }
        }

        try! (try! Yams.dump(
            object: ["targets": targets],
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
