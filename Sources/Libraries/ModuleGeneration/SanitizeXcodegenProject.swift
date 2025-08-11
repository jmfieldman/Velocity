//
//  SanitizeXcodegenProject.swift
//  Copyright © 2025 Jason Fieldman.
//

import ArgumentParser
import CryptoKit
import DependencyMagnetLib
import Foundation
import InternalUtilities
import ModuleManagementLib
import ProjectSpec
import SQLite
import Yams

private let kWorkDirectoryRoot = ".sanitization"
private let kShaDirectoryName = "modules"
private let kDerivedDataLibraryPath = "\(NSHomeDirectory())/Library/Developer/Xcode/DerivedData"

public struct SanitizeXcodegenProjectOptions {
    public let packageFileName: String
    public let xcodeprojPath: String
    public let modulesYmlPath: String
    public let projectYmlPaths: String
    public let xcodeConfiguration: String
    public let appName: String?

    public init(
        packageFileName: String,
        xcodeprojPath: String,
        modulesYmlPath: String,
        projectYmlPaths: String,
        xcodeConfiguration: String,
        appName: String?
    ) {
        self.packageFileName = packageFileName
        self.xcodeprojPath = xcodeprojPath
        self.modulesYmlPath = modulesYmlPath
        self.projectYmlPaths = projectYmlPaths
        self.xcodeConfiguration = xcodeConfiguration
        self.appName = appName
    }
}

public enum SanitizeXcodegenProject {
    public static func execute(with options: SanitizeXcodegenProjectOptions) throws {
        // Sanity checks

        guard options.xcodeprojPath.hasSuffix(".xcodeproj") else {
            try throwError(.invalidArgument, "Invalid xcodeproj path: \(options.xcodeprojPath) -- requires .xcodeproj extension")
        }

        guard FileManager.default.fileExists(atPath: options.xcodeprojPath) else {
            try throwError(.pathNotFound, ".xcodeproj not found at path: \(options.xcodeprojPath)")
        }

        guard FileManager.default.fileExists(atPath: options.modulesYmlPath) else {
            try throwError(.pathNotFound, "Modules yml file not found at: \(options.modulesYmlPath)")
        }

        let projectYmlPathArray = options.projectYmlPaths.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        try projectYmlPathArray.forEach {
            guard FileManager.default.fileExists(atPath: $0) else {
                try throwError(.pathNotFound, "Project yml source not found at: \($0)")
            }
        }

        // Variables

        let projectName = options.xcodeprojPath.removingSuffix(".xcodeproj").lastPathComponent
        let appName = options.appName ?? projectName
        let workDirectoryBase = "\(kWorkDirectoryRoot)/\(projectName)"
        let workDirectory = workDirectoryBase.prependingCurrentDirectory()
        let moduleShaDirectory = "\(workDirectory)/\(kShaDirectoryName)"

        vprint(.normal, "Sanitizing project: \(projectName)")
        vprint(.verbose, "Work directory: \(workDirectoryBase)")

        // Ensure the modules path is parsable

        let modulesYmlString = try String(
            contentsOf: URL(fileURLWithPath: options.modulesYmlPath.prependingCurrentDirectory()),
            encoding: .utf8
        )

        guard let modulesObject = try Yams.load(yaml: modulesYmlString) as? [String: Any],
              let targets = modulesObject["targets"] as? [String: [String: Any]]
        else {
            try throwError(.fileError, "modules yml at [\(options.modulesYmlPath)] does not contain a top-level 'targets' key")
        }

        // Collect all matches to remove from the build.db file

        var dbMatchesToRemove: [String] = [
            "\(appName).app",
            "\(appName).swiftmodule",
        ]

        // Determine derived data directory

        let derivedDataPath = "\(kDerivedDataLibraryPath)/\(projectName)-\(hashStringForPath(options.xcodeprojPath.prependingCurrentDirectory()))/Build"
        guard FileManager.default.fileExists(atPath: derivedDataPath) else {
            vprint(.normal, "Sanitization not required; no derived data directory at: \(derivedDataPath)")
            exit(0)
        }

        // Create module sha directory if needed

        try FileManager.default.createDirectory(atPath: moduleShaDirectory, withIntermediateDirectories: true, attributes: nil)

        // Step -- Remove top-level application product

        try removeApp(
            derivedDataPath: derivedDataPath,
            configuration: options.xcodeConfiguration,
            appName: options.appName ?? projectName
        )

        // Step -- Process modules

        try processModules(targets: targets, dbMatchesToRemove: &dbMatchesToRemove)

        // Final Step -- Clear all DB matches

        let dbPath = "\(derivedDataPath)/Intermediates.noindex/XCBuildData/build.db"
        if FileManager.default.fileExists(atPath: dbPath) {
            let dbLink = try Connection(dbPath)
            try dbLink.transaction {
                try dbMatchesToRemove.forEach {
                    try dbLink.run("DELETE FROM rule_results WHERE key_id IN (SELECT id FROM key_names WHERE key LIKE '%\($0)%')")
                    vprint(.debug, "DB Query: DELETE FROM rule_results WHERE key_id IN (SELECT id FROM key_names WHERE key LIKE '%\($0)%')")
                }
            }
        }
    }
}

private func removeApp(derivedDataPath: String, configuration: String, appName: String) throws {
    try safeDelete(path: "\(derivedDataPath)/Products/\(configuration)-iphoneos/\(appName).app", prefix: derivedDataPath)
    try safeDelete(path: "\(derivedDataPath)/Products/\(configuration)-iphoneos/\(appName).swiftmodule", prefix: derivedDataPath)
    try safeDelete(path: "\(derivedDataPath)/Products/\(configuration)-iphonesimulator/\(appName).app", prefix: derivedDataPath)
    try safeDelete(path: "\(derivedDataPath)/Products/\(configuration)-iphonesimulator/\(appName).swiftmodule", prefix: derivedDataPath)
    try removeTargetCache(derivedDataPath: derivedDataPath, matching: "\(appName).app")
}

private func removeTargetCache(derivedDataPath: String, matching: String) throws {
    let results = Process.shellOutput("grep -r \(matching) \(derivedDataPath)/Intermediates.noindex/XCBuildData/PIFCache/target -l").components(separatedBy: "\n")
    for result in results {
        let toRemove = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if toRemove.count > 0 {
            try safeDelete(path: toRemove, prefix: derivedDataPath)
        }
    }
}

private func safeDelete(path: String, prefix: String) throws {
    guard path.hasPrefix(prefix) else {
        try throwError(.invalidArgument, "safeDelete failed: [\(path)] not prefixed with: [\(prefix)]")
    }
    if FileManager.default.fileExists(atPath: path) {
        vprint(.verbose, "Deleting: \(path)")
        try FileManager.default.removeItem(atPath: path)
    } else {
        vprint(.debug, "Intent to delete path but no item exists: \(path)")
    }
}

private func processModules(targets: [String: [String: Any]], dbMatchesToRemove: inout [String]) throws {
    print("targets: \(targets.keys)")
}

private func hashStringForPath(_ path: String) -> String {
    // Char array that will contain the identifier
    var resultStr = [UInt8](repeating: 0, count: 28)

    let pathAsData = path.data(using: .utf8)!
    let md5Hash = Insecure.MD5.hash(data: pathAsData)

    let bytes = Array(md5Hash)
    let digest1 =
        UInt64(UInt64(bytes[0]) << 56) |
        UInt64(UInt64(bytes[1]) << 48) |
        UInt64(UInt64(bytes[2]) << 40) |
        UInt64(UInt64(bytes[3]) << 32) |
        UInt64(UInt64(bytes[4]) << 24) |
        UInt64(UInt64(bytes[5]) << 16) |
        UInt64(UInt64(bytes[6]) << 8) |
        UInt64(bytes[7])
    let digest2 =
        UInt64(UInt64(bytes[8]) << 56) |
        UInt64(UInt64(bytes[9]) << 48) |
        UInt64(UInt64(bytes[10]) << 40) |
        UInt64(UInt64(bytes[11]) << 32) |
        UInt64(UInt64(bytes[12]) << 24) |
        UInt64(UInt64(bytes[13]) << 16) |
        UInt64(UInt64(bytes[14]) << 8) |
        UInt64(bytes[15])
    let digest: [UInt64] = [digest1, digest2]

    // Take the first 8 bytes of the digest and swap byte order
    let startValue1 = digest[0].littleEndian

    // For indexes 13->0
    var index = 13
    var startValue = startValue1
    repeat {
        // Take 'startValue' mod 26 (restrict to alphabetic) and add based on 'a'
        resultStr[index] = UInt8(UInt8(startValue % 26) + Character("a").asciiValue!)

        // Divide 'startValue' by 26
        startValue /= 26

        index -= 1
    } while index >= 0

    // The second loop, this time using the last 8 bytes
    // Repeating the same process as before but over indexes 27->14
    let startValue2 = digest[1].littleEndian
    index = 27
    startValue = startValue2
    repeat {
        resultStr[index] = UInt8(UInt8(startValue % 26) + Character("a").asciiValue!)
        startValue /= 26
        index -= 1
    } while index > 13

    // Create a new string from the 'resultStr' char array and return
    return String(bytes: resultStr, encoding: .utf8) ?? ""
}
