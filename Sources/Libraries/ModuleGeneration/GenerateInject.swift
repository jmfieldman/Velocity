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
    public let packageFileName: String

    public init(
        modulesPath: String,
        outputFile: String,
        injectFunctionName: String,
        packageFileName: String
    ) {
        self.modulesPath = modulesPath
        self.outputFile = outputFile
        self.injectFunctionName = injectFunctionName
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

        for package in packages {
            guard case let injectsMap = package.injectMap, !injectsMap.isEmpty else {
                continue
            }

            guard let mainName = package.modules[.main]?.name else {
                vprint(.normal, "Warning: skipping package \(package.name) that declared injection without a main module.", "⚠️")
                continue
            }

            if let implName = package.modules[.impl]?.name {
                imports.insert(implName)
            }

            imports.insert(mainName)
            injectionMap.merge(injectsMap) { _, new in new }
        }

        vprint(.normal, "Generating injections for package count: \(injectionMap.count)", "🔧")

        do {
            vprint(.debug, "Generating base path: \(options.outputFile.basePath)", "🔧")
            try FileManager.default.createDirectory(atPath: options.outputFile.basePath, withIntermediateDirectories: true)

            let registrationString = injectionMap.keys.sorted().compactMap { name -> String? in
                guard let impl = injectionMap[name] else {
                    return nil
                }
                return "InjectionManager.register(\(name).self) { \(impl)() }"
            }.map {
                "        \($0)"
            }.joined(separator: "\n")

            let fileString = kFileTemplate
                .replacingOccurrences(of: "{IMPORTS}", with: imports.sorted().map { "import \($0)" }.joined(separator: "\n"))
                .replacingOccurrences(of: "{FUNCNAME}", with: options.injectFunctionName)
                .replacingOccurrences(of: "{REGISTRATION}", with: registrationString)

            try fileString.write(toFile: options.outputFile, atomically: true, encoding: .utf8)

        } catch {
            try throwError(.fileError, "Error outputting file: \(error.localizedDescription)")
        }
    }
}

private let kFileTemplate = """
import Inject
{IMPORTS}

public extension InjectionManager {
    public func {FUNCNAME}() {
{REGISTRATION}
    }
}
"""
