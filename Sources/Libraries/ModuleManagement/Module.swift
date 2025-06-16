//
//  Module.swift
//  Copyright © 2024 Jason Fieldman.
//

import Foundation
import InternalUtilities
import ProjectSpec
import Yams

private let kImportsYml = "imports.yml"
private let kInfoPlist = "Info.plist"
private let importsDecoder = YAMLDecoder()

public final class Module {
    public let name: String
    public let type: ModuleType

    /// The absolute base path of the module
    public let absoluteBasePath: String

    /// The base path within the top-level project scope
    public let projectBasePath: String

    private lazy var importsFilePath = self.absoluteBasePath + kImportsYml

    init(name: String, type: ModuleType, absoluteBasePath: String, projectBasePath: String) {
        self.name = name
        self.type = type
        self.absoluteBasePath = absoluteBasePath
        self.projectBasePath = projectBasePath
    }

    public private(set) lazy var importedModules: [String] = self.regenerateImportsIfNecessary()

    private func regenerateImportsIfNecessary() -> [String] {
        (try? String(contentsOfFile: importsFilePath, encoding: .utf8)).flatMap {
            try? importsDecoder.decode([String].self, from: $0)
        } ?? (regenerateImportsFile(ignoreFilenames: []) ?? [])
    }

    @discardableResult public func regenerateImportsFile(
        ignoreFilenames: Set<String>
    ) -> [String]? {
        guard let imports = SwiftImportDetector.execute(
            path: absoluteBasePath,
            deepSearch: true,
            ignoreFilenames: ignoreFilenames
        )?.sorted() else {
            return nil
        }

        // Delete stray imports.yml if there are no imports in the module
        guard imports.count > 0 else {
            try? FileManager.default.removeItem(atPath: importsFilePath)
            return []
        }

        if var node = try? Yams.Node(imports) {
            node.sequence?.style = .block
            if let string = try? Yams.serialize(node: node) {
                try? string.write(toFile: importsFilePath, atomically: true, encoding: .utf8)
            }
        }

        return imports
    }

    public func regenInfoPlists() throws {
        let plistTemplate = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDevelopmentRegion</key>
            <string>$(DEVELOPMENT_LANGUAGE)</string>
            <key>CFBundleExecutable</key>
            <string>$(EXECUTABLE_NAME)</string>
            <key>CFBundleIdentifier</key>
            <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
            <key>CFBundleInfoDictionaryVersion</key>
            <string>6.0</string>
            <key>CFBundleName</key>
            <string>$(PRODUCT_NAME)</string>
            <key>CFBundlePackageType</key>
            <string>FMWK</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0.0</string>
            <key>CFBundleVersion</key>
            <string>0</string>
            <key>NSPrincipalClass</key>
            <string></string>
        </dict>
        </plist>
        """
        let path = absoluteBasePath.appendingMissingSlash().appending(kInfoPlist)
        try plistTemplate.write(toFile: path, atomically: true, encoding: .utf8)
    }

    public private(set) lazy var target: ProjectSpec.Target = generateTarget()

    private func generateTarget() -> ProjectSpec.Target {
        ProjectSpec.Target(
            name: name,
            type: .framework,
            platform: .auto,
            sources: [
                TargetSource(
                    path: projectBasePath.removingSlash(),
                    excludes: [kImportsYml]
                ),
            ],
            dependencies: importedModules.map {
                Dependency(
                    type: .framework,
                    reference: $0
                )
            }
        )
    }
}
