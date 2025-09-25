//
//  GenerateInject.swift
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

public struct GenerateInjectOptions {
    public let modulesPath: String
    public let outputFile: String
    public let injectFunctionName: String
    public let builderFunctionName: String
    public let packageFileName: String

    public init(
        modulesPath: String,
        outputFile: String,
        injectFunctionName: String,
        builderFunctionName: String,
        packageFileName: String
    ) {
        self.modulesPath = modulesPath
        self.outputFile = outputFile
        self.injectFunctionName = injectFunctionName
        self.builderFunctionName = builderFunctionName
        self.packageFileName = packageFileName
    }
}

public enum GenerateInject {
    public static func execute(with options: GenerateInjectOptions) throws {
        let absoluteModuleBasePath = options.modulesPath.prependingCurrentDirectory()
        let absoluteProjectPath = FileManager.default.currentDirectoryPath

        // Verify root path exists
        guard FileManager.default.directoryExists(atPath: absoluteModuleBasePath) else {
            try throwError(.pathNotFound, "Module directory not found at path: \(options.modulesPath)")
        }

        let packages = ModulePackageManager.packages(
            named: options.packageFileName,
            root: options.modulesPath,
            absoluteProjectPath: absoluteProjectPath
        )

        guard packages.count > 0 else {
            vprint(.normal, "No packages found at root path: \(options.modulesPath)")
            return
        }

        var imports: Set<String> = []
        var injectionMap: [String: String] = [:]
        var buildersMap: [String: String] = [:]

        // Parse injections
        for package in packages {
            guard case let injectsMap = package.injectMap, !injectsMap.isEmpty else {
                continue
            }

            guard let mainName = package.modules[.main]?.name else {
                vprint(.normal, "Warning: skipping injection for package \(package.name) that declared injection without a main module.", "⚠️")
                continue
            }

            if let implName = package.modules[.impl]?.name {
                imports.insert(implName)
            }

            try injectsMap.keys.forEach {
                if injectionMap[$0] != nil {
                    try throwError(.duplicateInjections, "Duplicate injection declarations for \($0)")
                }
            }

            imports.insert(mainName)
            injectionMap.merge(injectsMap) { _, new in new }
        }

        // Parse builders
        for package in packages {
            guard case let builderMap = package.builderMap, !builderMap.isEmpty else {
                continue
            }

            guard let mainName = package.modules[.main]?.name else {
                vprint(.normal, "Warning: skipping builders package \(package.name) that declared builders without a main module.", "⚠️")
                continue
            }

            if let implName = package.modules[.impl]?.name {
                imports.insert(implName)
            }

            try builderMap.keys.forEach {
                if buildersMap[$0] != nil {
                    try throwError(.duplicateInjections, "Duplicate injection declarations for \($0)")
                }
            }

            imports.insert(mainName)
            buildersMap.merge(builderMap) { _, new in new }
        }

        if !injectionMap.isEmpty {
            vprint(.normal, "Generating injections for package count: \(injectionMap.count)", "🔧")
        }

        if !buildersMap.isEmpty {
            vprint(.normal, "Generating builders for package count: \(buildersMap.count)", "🔧")
        }

        do {
            vprint(.debug, "Generating base path: \(options.outputFile.basePath)", "🔧")
            try FileManager.default.createDirectory(atPath: options.outputFile.basePath, withIntermediateDirectories: true)

            let injectRegistrationString = injectionMap.keys.sorted().compactMap { name -> String? in
                guard let impl = injectionMap[name] else {
                    return nil
                }
                return "InjectionManager.unsafeRegister(\(name).self) { \(impl)() }"
            }.map {
                "        \($0)"
            }.joined(separator: "\n")

            let injectActivationString = injectionMap.keys.sorted().compactMap { name -> String? in
                return "let _ = Inject(\(name).self)"
            }.map {
                "        \($0)"
            }.joined(separator: "\n")

            let builderRegistrationString = buildersMap.keys.sorted().compactMap { builderName -> String? in
                guard let impl = buildersMap[builderName] else {
                    return nil
                }
                return "BuilderManager.unsafeRegister(\(builderName).self) { \(impl)(builder: $0 as! \(builderName)) }"
            }.map {
                "        \($0)"
            }.joined(separator: "\n")

            let fileString = kFileTemplate
                .replacingOccurrences(of: "{IMPORTS}", with: imports.sorted().map { "import \($0)" }.joined(separator: "\n"))
                .replacingOccurrences(of: "{INJECT_FUNCNAME}", with: options.injectFunctionName)
                .replacingOccurrences(of: "{INJECT_REGISTRATION}", with: injectRegistrationString)
                .replacingOccurrences(of: "{INJECT_ACTIVATION}", with: injectActivationString)
                .replacingOccurrences(of: "{BUILDER_FUNCNAME}", with: options.builderFunctionName)
                .replacingOccurrences(of: "{BUILDER_REGISTRATION}", with: builderRegistrationString)

            try fileString.write(toFile: options.outputFile, atomically: true, encoding: .utf8)

        } catch {
            try throwError(.fileError, "Error outputting file: \(error.localizedDescription)")
        }
    }
}

private let kFileTemplate = """
@_exported import Inject
{IMPORTS}

public extension InjectionManager {
    static func {INJECT_FUNCNAME}() {
{INJECT_REGISTRATION}
    }

    static func activateInjections() {
{INJECT_ACTIVATION}
    }
}

public extension BuilderManager {
    @MainActor static func {BUILDER_FUNCNAME}() {
{BUILDER_REGISTRATION}
    }
}
"""
