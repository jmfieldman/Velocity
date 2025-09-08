//
//  GenerateXcodegenModules.swift
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

public struct GenerateXcodegenModulesOptions {
    public let rootPath: String
    public let regenImports: Bool
    public let regenInfoPlists: Bool
    public let outputFilename: String
    public let platforms: String
    public let dependenciesConfig: String
    public let packageFileName: String
    public let defaultStatic: Bool

    public init(
        rootPath: String,
        regenImports: Bool = false,
        regenInfoPlists: Bool = false,
        outputFilename: String = "project-modules.yml",
        platforms: String = "iOS",
        dependenciesConfig: String = kPathDependencyConfig,
        packageFileName: String = kPathPackageYml,
        defaultStatic: Bool = false
    ) {
        self.regenImports = regenImports
        self.regenInfoPlists = regenInfoPlists
        self.rootPath = rootPath
        self.outputFilename = outputFilename
        self.platforms = platforms
        self.dependenciesConfig = dependenciesConfig
        self.packageFileName = packageFileName
        self.defaultStatic = defaultStatic
    }
}

public enum GenerateXcodegenModules {
    public static func execute(with options: GenerateXcodegenModulesOptions) throws {
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

        let packageManager = ModulePackageManager(packages: packages)

        if let cycles = packageManager.importCycle(), let last = cycles.last {
            for cycle in cycles {
                vprint(.normal, "> \(cycle.0) -> \(cycle.1.name)\(cycle.1.bridge.flatMap { ":\($0)" } ?? "")")
            }
            try throwError(.dependencyCycle, "Found dependency cycle: \(last.0) -> \(last.1.name)\(last.1.bridge.flatMap { ":\($0)" } ?? "")")
        } else {
            vprint(.verbose, "No dependency cycles found")
        }

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
            dependenciesConfig.projectPackages?.forEach { projectPkg in
                if let libs = projectPkg.libraries, libs.count > 0 {
                    libs.forEach { dependencyLookup[$0] = projectPkg.dependencyConfig() }
                } else {
                    dependencyLookup[projectPkg.name] = projectPkg.dependencyConfig()
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

        // Checking dynamic -> static deps
        var dynamicInternalModules: [String: Bool] = [:]
        var internalDepMap: [String: [String]] = [:]

        var targets: [String: TargetEnc] = [:]
        var templateDeps: [DependencyEnc] = []
        packages.sorted { $0.name < $1.name }.forEach { package in
            package.modules.keys.sorted { $0.rawValue < $1.rawValue }.forEach { moduleType in
                let module = package.modules[moduleType]!

                // Determine dependencies

                // Process the imported modules to generate internal and external dependencies
                let (internalDependencies, externalRefs) = module.importedModules.sorted().reduce(into: ([DependencyEnc](), [String: [String]]())) { result, depName in
                    if internalModuleSet.contains(depName) {
                        // Append internal dependencies
                        result.0.append(DependencyEnc(target: depName))
                        internalDepMap[module.name] = (internalDepMap[module.name] ?? []) + [depName]
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

                // dynamic vs. static

                let useDynamic = package.forceDynamicFramework.flatMap { $0 } ?? !options.defaultStatic
                dynamicInternalModules[module.name] = useDynamic

                // Additional resources

                let additionalResources: [TargetSource] = []
                /*
                   xcodegen seems to be able to auto-detect the resource phase for files at the root path.
                   leaving this out for now unless it becomes apparent that we'd want to include resources
                   outside of the main module directory

                 let additionalResources: [TargetSource] = module.resources.map { resources in
                     resources.map {
                         TargetSource(
                             path: module.projectBasePath.appendingMissingSlash() + $0,
                             buildPhase: .resources
                         )
                     }
                 } ?? []
                  */

                // Generate Target object

                let target = ProjectSpec.Target(
                    name: module.name,
                    type: module.type.xcodeProductType(dynamicPackage: useDynamic),
                    platform: .auto,
                    supportedDestinations: supportedDestinations,
                    sources: [.init(
                        path: module.projectBasePath,
                        excludes: module.fileExclusions
                    )] + additionalResources
                )

                targets[module.name] = TargetEnc(
                    type: target.type.rawValue.replacingOccurrences(of: "com.apple.product-type.", with: ""),
                    platform: target.platform.rawValue,
                    supportedDestinations: supportedDestinations.map(\.rawValue),
                    dependencies: dependencies,
                    sources: target.sources.map {
                        SourceEnc(
                            path: $0.path,
                            excludes: $0.excludes,
                            buildPhase: $0.buildPhase?.toJSONValue() as? String
                        )
                    }
                )

                // Include in main app template

                if moduleType.includeInAppTemplate {
                    templateDeps.append(DependencyEnc(target: module.name))
                }

                // Resource warning + extensions

                if module.resources.count > 0 {
                    if moduleType.mayContainResources {
                        let bundleResourceExtensionPath = module.projectBasePath.appendingMissingSlash() + "Bundle+ResourceExtension.swift"

                        // Create bundle extension for resource-containing modules
                        if !FileManager.default.fileExists(atPath: bundleResourceExtensionPath) {
                            try? kBundleResourceExtensionTemplate
                                .replacingOccurrences(of: "{MODULE_NAME}", with: module.name)
                                .write(toFile: module.projectBasePath.appendingMissingSlash() + "Bundle+ResourceExtension.swift", atomically: true, encoding: .utf8)
                        }
                    } else {
                        // Otherwise warn the user
                        vprint(.normal, "WARNING: module [\(module.name)] contains resources, but is not a resource module type.")
                        for resource in module.resources {
                            vprint(.normal, " > \(resource)")
                        }
                    }
                }

                if module.resources.count == 0, moduleType.mustContainResources {
                    vprint(.normal, "WARNING: resource module [\(module.name)] does not contain any resources.")
                }
            }
        }

        let targetsEnc = TargetsEnc(
            targets: targets,
            targetTemplates: ["ModuleInclusionTemplate": TargetTemplateEnc(dependencies: templateDeps)]
        )
        let encoder = YAMLEncoder()
        encoder.options = Emitter.Options(sortKeys: true, sequenceStyle: .block, mappingStyle: .block)
        let encodedString = try encoder.encode(targetsEnc)

        try! encodedString.removingEmptyYml().write(
            toFile: options.outputFilename,
            atomically: true,
            encoding: .utf8
        )

        // Throw warning if dynamic -> static dependency is detected
        var dynamicViolationsDetected = false
        for (module, dynamic) in dynamicInternalModules {
            guard dynamic, let moduleDeps = internalDepMap[module] else { continue }
            for moduleDep in moduleDeps {
                if dynamicInternalModules[moduleDep] == false {
                    vprint(.normal, "Dynamic module [\(module)] depends on static module [\(moduleDep)]", "⚠️ ")
                    dynamicViolationsDetected = true
                }
            }
        }

        if dynamicViolationsDetected {
            vprint(.normal, "It is incorrect practice to have a dynamic framework depend on a static framework. This can lead to duplicate symbol problems, and framework size bloat. Refactor your dependency graph so that dynamic frameworks are only dependent on other dynamic frameworks.", "⚠️ ")
        }
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
    var targetTemplates: [String: TargetTemplateEnc]
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
    var buildPhase: String?
}

private struct TargetTemplateEnc: Encodable {
    var dependencies: [DependencyEnc]
}

private extension ModuleType {
    var includeInAppTemplate: Bool {
        switch self {
        case .main, .impl, .resources:
            true
        case .tests, .testHelpers:
            false
        }
    }
}

// MARK: Bundle+ResourceExtension

let kBundleResourceExtensionTemplate = """
import Foundation

// This file is autogenerated by Velocity to provide a way to programmatically
// access this Bundle

public extension Bundle {
    /// Access the {MODULE_NAME} bundle 
    static let {MODULE_NAME} = Bundle(for: {MODULE_NAME}Beacon.self)
    private class {MODULE_NAME}Beacon {}
}
"""
