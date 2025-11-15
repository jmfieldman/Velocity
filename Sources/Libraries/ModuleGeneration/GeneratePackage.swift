//
//  GeneratePackage.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import DependencyMagnetLib
import Foundation
import InternalUtilities
import ModuleManagementLib
import ProjectSpec
import Yams

public struct GeneratePackageOptions {
    public let regenImports: Bool
    public let rootPath: String
    public let swiftToolsVersion: String
    public let platforms: String
    public let dependenciesConfig: String
    public let dependencyOutputPath: String?
    public let ignoreDependencies: [String]
    public let packageName: String?
    public let defaultLocalization: String
    public let warningsAsErrors: Bool
    public let packageFileName: String

    public init(
        regenImports: Bool,
        rootPath: String,
        swiftToolsVersion: String,
        platforms: String,
        dependenciesConfig: String,
        dependencyOutputPath: String?,
        ignoreDependencies: [String],
        packageName: String?,
        defaultLocalization: String,
        warningsAsErrors: Bool,
        packageFileName: String = "Package.swift",
    ) {
        self.regenImports = regenImports
        self.rootPath = rootPath
        self.swiftToolsVersion = swiftToolsVersion
        self.platforms = platforms
        self.dependenciesConfig = dependenciesConfig
        self.dependencyOutputPath = dependencyOutputPath
        self.ignoreDependencies = ignoreDependencies
        self.packageName = packageName
        self.defaultLocalization = defaultLocalization
        self.warningsAsErrors = warningsAsErrors
        self.packageFileName = packageFileName
    }
}

public enum GeneratePackage {
    public static func execute(with options: GeneratePackageOptions) throws {
        let projectPath = options.rootPath.prependingCurrentDirectory()

        // Verify root path exists
        guard FileManager.default.directoryExists(atPath: projectPath) else {
            try throwError(.pathNotFound, "Directory not found at root path: \(projectPath)")
        }

        let packages = ModulePackageManager.packages(
            named: options.packageFileName,
            root: projectPath,
            absoluteProjectPath: projectPath
        )

        let packageManager = ModulePackageManager(packages: packages)

        guard packages.count > 0 else {
            vprint(.normal, "No packages found at root path: \(projectPath)")
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

        if let cycles = packageManager.importCycle(), let last = cycles.last {
            for cycle in cycles {
                vprint(.normal, "> \(cycle.0) -> \(cycle.1.name)\(cycle.1.bridge.flatMap { ":\($0)" } ?? "")")
            }
            try throwError(.dependencyCycle, "Found dependency cycle: \(last.0) -> \(last.1.name)\(last.1.bridge.flatMap { ":\($0)" } ?? "")")
        } else {
            vprint(.verbose, "No dependency cycles found")
        }

        vprint(.normal, "Generating \(options.rootPath)/Package.swift", "🔧")

        let packageContents = try kPackageSwiftTemplate
            .replacingOccurrences(of: "{SWIFT_TOOLS}", with: options.swiftToolsVersion)
            .replacingOccurrences(of: "{PACKAGE_NAME}", with: gen_PACKAGE_NAME(options: options))
            .replacingOccurrences(of: "{DEFAULT_LOCALIZATION}", with: options.defaultLocalization)
            .replacingOccurrences(of: "{PLATFORMS}", with: options.platforms)
            .replacingOccurrences(of: "{PRODUCTS}", with: gen_PRODUCTS(packageManager: packageManager))
            .replacingOccurrences(of: "{DEPENDENCIES}", with: gen_DEPENDENCIES(options: options))
            .replacingOccurrences(of: "{TARGETS}", with: gen_TARGETS(packageManager: packageManager, projectPath: projectPath, options: options))
            .prettified()

        try! packageContents.write(
            toFile: "\(projectPath)/Package.swift",
            atomically: true,
            encoding: .utf8
        )
    }

    private static func gen_PACKAGE_NAME(options: GeneratePackageOptions) -> String {
        options.packageName ?? options.rootPath.lastPathComponent
    }

    private static func gen_DEPENDENCIES(options: GeneratePackageOptions) throws -> String {
        guard FileManager.default.fileExists(atPath: options.dependenciesConfig) else {
            vprint(.normal, "Warning, no external dependencies config found at path: \(options.dependenciesConfig)", "❗")
            return ""
        }

        let dependenciesConfig = try DependenciesConfig.from(filePath: options.dependenciesConfig)
        guard let dependencies = dependenciesConfig.dependencies, dependencies.count > 0 else {
            return ""
        }

        let ignoredDependencies: Set<String> = Set(options.ignoreDependencies)
        return try dependencies.filter {
            !ignoredDependencies.contains($0.inferredPackageName)
        }.map { dependency -> String in
            guard dependency.keepRemote != true else {
                return try dependency.packageString()
            }

            // Determine the name of the dependency package
            let dependencyPackageName = dependency.inferredPackageName

            guard let dependencyOutputPath = options.dependencyOutputPath else {
                vprint(.normal, "Warning, no dependencyOutputPath was specified; \(dependencyPackageName) will use remote package", "❗")
                return try dependency.packageString()
            }

            let dependencyPackagePath = "\(dependencyOutputPath)/Packages/\(dependencyPackageName)"
            guard FileManager.default.directoryExists(atPath: dependencyPackagePath) else {
                vprint(.normal, "Warning, no local package exists at \(dependencyPackagePath); \(dependencyPackageName) will use remote package", "❗")
                return try dependency.packageString()
            }

            let path = dependencyPackagePath.prependingCurrentDirectory().relative(to: options.rootPath.prependingCurrentDirectory())
            return ".package(name: \"\(dependencyPackageName)\", path: \"\(path)\")"
        }.map { "\($0)," }.joined(separator: "\n")
    }

    private static func gen_TARGETS(
        packageManager: ModulePackageManager,
        projectPath: String,
        options: GeneratePackageOptions
    ) throws -> String {
        var externalImports: [String: String] = [:]
        if
            FileManager.default.fileExists(atPath: options.dependenciesConfig),
            case let dependenciesConfig = try DependenciesConfig.from(filePath: options.dependenciesConfig),
            let dependencies = dependenciesConfig.dependencies,
            dependencies.count > 0
        {
            for dependency in dependencies {
                if let libraries = dependency.libraries, libraries.count > 0 {
                    for library in libraries {
                        externalImports[library] = ".product(name: \"\(library)\", package: \"\(dependency.inferredPackageName)\")"
                    }
                } else {
                    externalImports[dependency.inferredPackageName] = ".product(name: \"\(dependency.inferredPackageName)\", package: \"\(dependency.inferredPackageName)\")"
                }
            }
        }

        var knownModules: Set<String> = []
        for package in packageManager.packages {
            for value in package.modules.values {
                knownModules.insert(value.name)
            }
        }

        var targets: [String] = []
        packageManager.packages.sorted { $0.name < $1.name }.forEach { package in
            package.modules.keys.sorted { $0.rawValue < $1.rawValue }.forEach { key in
                guard let module = package.modules[key] else { return }

                var deps: [String] = []
                for dep in packageManager.importGraph[module.name] ?? [] {
                    if let externalImport = externalImports[dep.name] {
                        deps.append("\(externalImport),")
                    } else if knownModules.contains(dep.name) {
                        deps.append("\"\(dep.name)\",")
                    }
                }

                let swiftSettings: String = options.warningsAsErrors ? ",\nswiftSettings: [.treatAllWarnings(as: .error)]" : ""

                let targetStr = """
                .target(
                  name: "\(module.name)",
                  dependencies: [
                    \(deps.sorted().joined(separator: "\n"))
                  ],
                  path: "\(module.absoluteBasePath.relative(to: projectPath))",
                  exclude: [
                    \(module.fileExclusions.sorted().map { "\"\($0)\"," }.joined(separator: "\n"))
                  ]{SWIFTSETTINGS}
                ),
                """
                .replacingOccurrences(of: "{SWIFTSETTINGS}", with: swiftSettings)

                targets.append(targetStr)
            }
        }

        return targets.joined(separator: "\n")
    }

    private static func gen_PRODUCTS(
        packageManager: ModulePackageManager
    ) -> String {
        var result: [String] = []
        packageManager.packages.sorted { $0.name < $1.name }.forEach { package in
            package.modules.keys.sorted { $0.rawValue < $1.rawValue }.forEach { key in
                guard let module = package.modules[key] else { return }
                result.append(".library(name: \"\(module.name)\", targets: [\"\(module.name)\"]),")
            }
        }

        return result.joined(separator: "\n")
    }
}

private let kPackageSwiftTemplate = """
// swift-tools-version:{SWIFT_TOOLS}

import PackageDescription

let package = Package(
    name: "{PACKAGE_NAME}",
    defaultLocalization: "{DEFAULT_LOCALIZATION}",
    platforms: [
        {PLATFORMS}
    ],
    products: [
{PRODUCTS}
    ],
    dependencies: [
{DEPENDENCIES}
    ],
    targets: [
{TARGETS}
    ]
)
"""

private extension String {
    func prettified() -> String {
        var result = ""
        var indent = 0
        for line in split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix(")") || trimmed.hasPrefix("]") {
                indent -= 4
            }
            let indented = String(repeating: " ", count: indent) + trimmed
            if trimmed.hasSuffix("(") || trimmed.hasSuffix("[") {
                indent += 4
            }
            result += indented + "\n"
        }
        return result
    }
}
