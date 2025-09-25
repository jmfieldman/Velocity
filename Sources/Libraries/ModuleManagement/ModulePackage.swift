//
//  ModulePackage.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation
import Yams

private let kDefaultNameChar = "_"
private let kDefaultNameImpl = "Impl"
private let yamlDecoder = YAMLDecoder()

public final class ModulePackage {
    public let name: String
    private let config: ModulePackageConfig

    /// Absolute path the the package.yml for this ModulePackage
    private let filePath: String

    /// The absolute base path of `filePath` with trailing slash
    private let absoluteBasePath: String

    /// The base path within the top-level project scope
    private let projectBasePath: String

    /// Modules contained in this package
    public private(set) lazy var modules: [ModuleType: Module] = self.scanModules()

    public private(set) lazy var settingsOverrides: [ModuleType: [String: String]] = self.config.settingsOverrides?.mapKeys { ModuleType(rawValue: $0) } ?? [:]

    private lazy var fileExclusions: [ModuleType: [String]] = self.config.fileExclusions?.mapKeys { ModuleType(rawValue: $0) } ?? [:]

    private lazy var resources: [ModuleType: [String]] = self.config.resources?.mapKeys { ModuleType(rawValue: $0) } ?? [:]

    public private(set) lazy var quashActivation: Bool = config.quashActivation ?? false

    public private(set) lazy var generateMocks: Bool = {
        let hasInjections = injectMap.count > 0 || builderMap.count > 0
        return config.generateMocks ?? hasInjections
    }()

    public init?(
        packageFilePath: String,
        absoluteProjectPath: String
    ) {
        guard var fileContents = try? String(contentsOfFile: packageFilePath, encoding: .utf8) else {
            return nil
        }

        // An empty package.yml should be allowed, and considered an empty dictionary.
        if fileContents.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            fileContents = "{}"
        }

        guard let config = try? yamlDecoder.decode(ModulePackageConfig.self, from: fileContents, userInfo: [:]) else {
            return nil
        }

        let absoluteBasePath = (packageFilePath as NSString).deletingLastPathComponent

        self.config = config
        self.filePath = packageFilePath
        self.absoluteBasePath = packageFilePath.basePath.appendingMissingSlash()
        self.projectBasePath = absoluteBasePath.relative(to: absoluteProjectPath).appendingMissingSlash()
        self.name = absoluteBasePath.lastPathComponent
    }

    public private(set) lazy var injectMap: [String: String] = {
        if let map = config.injectMap, map.count > 0 {
            return map
        }

        if let injects = config.injects {
            if injects == kDefaultNameChar {
                return [name: "\(name)\(kDefaultNameImpl)"]
            } else if injects.count > 0 {
                return [injects: "\(injects)\(kDefaultNameImpl)"]
            }
        }

        return [:]
    }()

    public private(set) lazy var builderMap: [String: String] = {
        if let map = config.builderMap, map.count > 0 {
            return map
        }

        if let builders = config.builders {
            return builders.reduce(into: [:]) { result, builder in
                result["\(builder)Builder"] = "\(builder)Impl"
            }
        }

        return [:]
    }()

    public var forceDynamicFramework: Bool? {
        config.dynamic
    }

    // MARK: Private Helpers

    private func moduleNameFor(type: ModuleType) -> String {
        type.directory(for: name)
    }

    private func scanModules() -> [ModuleType: Module] {
        guard config.disable.flatMap({ !$0 }) ?? true else { return [:] }

        let codeCheck: (String) -> Bool = {
            $0.hasSuffix(".swift")
        }

        let resourceCheck: (String) -> Bool = { filename in
            [
                ".strings",
                ".xcassets",
                ".xcdatamodeld",
                ".xcdatamodel",
                ".plist",
                ".png",
                ".jpeg",
                ".jpg",
                ".heic",
                ".pdf",
                ".svg",
                ".xib",
            ].contains(where: { filename.hasSuffix($0) })
        }

        return Dictionary(uniqueKeysWithValues: ModuleType.allCases.compactMap { type in
            let moduleDirectory = "\(self.absoluteBasePath)\(type.directory(for: self.name))"
            if FileManager.default.directoryExists(atPath: moduleDirectory) {
                if type.mustContainCode, !FileManager.default.directory(at: moduleDirectory, contains: codeCheck) {
                    return nil
                }

                let detectedResources = FileManager.default.files(at: moduleDirectory, matching: resourceCheck)
                    .map { $0.replacingOccurrences(of: moduleDirectory.appendingMissingSlash(), with: "") }

                return (type, Module(
                    name: self.moduleNameFor(type: type),
                    type: type,
                    absoluteBasePath: "\(moduleDirectory)/",
                    projectBasePath: "\(self.projectBasePath)\(type.directory(for: self.name))/",
                    resources: Set(detectedResources + (resources[type] ?? [])),
                    fileExclusions: Set(fileExclusions[type] ?? [])
                ))
            }

            return nil
        })
    }
}
