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
import XcodeProj
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
    public let regenInfoPlists: Bool
    public let outputFilename: String
    public let platforms: String
    public let dependenciesConfig: String
    public let packageFileName: String

    public init(
        rootPath: String,
        regenImports: Bool = false,
        regenInfoPlists: Bool = false,
        outputFilename: String = "project-modules.yml",
        platforms: String = "iOS",
        dependenciesConfig: String = "Dependencies/dependencies.yml",
        packageFileName: String = "package.yml"
    ) {
        self.regenImports = regenImports
        self.regenInfoPlists = regenInfoPlists
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

        var dependencyLookup: [String: DependencyConfig] = [:]
        do {
            let dependenciesConfig = try DependenciesConfig.from(filePath: options.dependenciesConfig)
            dependenciesConfig.dependencies?.forEach { pkg in
                if let libs = pkg.libraries, libs.count > 0 {
                    libs.forEach { dependencyLookup[$0] = pkg }
                } else {
                    dependencyLookup[pkg.inferredPackageName] = pkg
                }
            }
            if dependencyLookup.count == 0 {
                vprint(.verbose, "No external dependencies were detected at \(options.dependenciesConfig)")
            }
        } catch {
            guard let cmdError = error as? CommandError else {
                return
            }
            switch cmdError {
            case .configNotFound:
                vprint(.verbose, "No dependency config file detected at \(options.dependenciesConfig)")
            case .configNotDecodable:
                vprint(.verbose, "Malformed/unparsable dependency config file at \(options.dependenciesConfig)")
            default:
                vprint(.error, "Failed to parse dependency config file at \(options.dependenciesConfig): \(error)")
            }
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

        if options.regenInfoPlists {
            vprint(.normal, "Regenerate Info.plist for \(packages.count) package\(packages.count == 1 ? "" : "s")", "🔧")
            try packages.sorted { $0.name < $1.name }.forEach { package in
                try package.modules.values.sorted { $0.name < $1.name }.forEach { module in
                    vprint(.debug, "Regenerate Info.plist for \(module.name)", "🔧")
                    try module.regenInfoPlists()
                }
            }
        }

        // Load our internal module set
        let internalModuleSet = Set(packages.flatMap { package in
            package.modules.values.map(\.name)
        })

        vprint(.normal, "Generating \(options.outputFilename)", "🔧")

        var targets: [String: TargetEnc] = [:]
        packages.sorted { $0.name < $1.name }.forEach { package in
            package.modules.keys.sorted { $0.rawValue < $1.rawValue }.forEach { moduleType in
                let module = package.modules[moduleType]!

                // Determine dependencies

                // Process the imported modules to generate internal and external dependencies
                let (internalDependencies, externalRefs) = module.importedModules.sorted().reduce(into: ([DependencyEnc](), [String: [String]]())) { result, depName in
                    if internalModuleSet.contains(depName) {
                        // Append internal dependencies
                        result.0.append(DependencyEnc(target: depName))
                    } else if let depConfig = dependencyLookup[depName] {
                        // Build external references
                        result.1[depConfig.inferredPackageName, default: []].append(depName)
                    }
                }

                // Convert external references into dependencies and log them
                let externalDependencies = externalRefs
                    .sorted(by: { $0.key < $1.key })
                    .map { ref -> DependencyEnc in
                        DependencyEnc(package: ref.key, products: ref.value)
                    }

                // Combine internal and external dependencies
                let dependencies = internalDependencies + externalDependencies

                // Determine source exclusions

                let exclusions = (kDefaultExclusionList + (package.fileExclusions[moduleType] ?? []))

                // Generate Target object

                let target = ProjectSpec.Target(
                    name: module.name,
                    type: module.type == .tests ? .unitTestBundle : .framework,
                    platform: .auto,
                    supportedDestinations: supportedDestinations,
                    sources: [.init(
                        path: module.projectBasePath,
                        excludes: exclusions
                    )]
                )

                targets[module.name] = TargetEnc(
                    type: target.type.rawValue.replacingOccurrences(of: "com.apple.product-type.", with: ""),
                    platform: target.platform.rawValue,
                    supportedDestinations: supportedDestinations.map(\.rawValue),
                    dependencies: dependencies,
                    sources: target.sources.map {
                        SourceEnc(
                            path: $0.path,
                            excludes: $0.excludes
                        )
                    }
                )
            }
        }

        let targetsEnc = TargetsEnc(targets: targets)
        let encoder = YAMLEncoder()
        encoder.options = Emitter.Options(sortKeys: true, sequenceStyle: .block, mappingStyle: .block)
        let encodedString = try encoder.encode(targetsEnc)

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

private struct TargetsEnc: Encodable {
    var targets: [String: TargetEnc]
}

private struct TargetEnc: Encodable {
    var type: String
    var platform: String
    var supportedDestinations: [String]
    var dependencies: [DependencyEnc]
    var sources: [SourceEnc]
}

private struct DependencyEnc: Encodable {
    var target: String?
    var embed: Bool?
    var framework: String?
    var sdk: String?

    var package: String?
    var products: [String]?
}

private struct SourceEnc: Encodable {
    var path: String
    var excludes: [String]
}
