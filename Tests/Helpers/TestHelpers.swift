//
//  TestHelpers.swift
//  Copyright © 2025 Jason Fieldman.
//

import Foundation
import InternalUtilities
import XCTest

public class TestHelpers {
    private static let testDirectory = "/tmp/VelocityTests"

    public static func initializeTest(
        basePath: String,
        directory: String
    ) throws -> String {
        let targetTestPath = TestHelpers.testDirectory.appendingMissingSlash() + directory
        let sourcePath = basePath.appendingMissingSlash() + directory

        // Clean existing files
        if FileManager.default.directoryExists(atPath: targetTestPath) {
            try FileManager.default.removeItem(atPath: targetTestPath)
        }

        // Create root path if it does not exist
        if !FileManager.default.fileExists(atPath: TestHelpers.testDirectory) {
            try FileManager.default.createDirectory(atPath: testDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        // Copy files
        try FileManager.default.copyItem(atPath: sourcePath, toPath: targetTestPath)

        return targetTestPath
    }

    public static func validateTestDirectoryAndSetCurrent(
        _ path: String
    ) {
        let setupPath = path.appendingMissingSlash() + "Setup"
        let expectationPath = path.appendingMissingSlash() + "Expectation"

        XCTAssert(FileManager.default.directoryExists(atPath: setupPath))
        XCTAssert(FileManager.default.directoryExists(atPath: expectationPath))

        FileManager.default.changeCurrentDirectoryPath(setupPath)
    }
}
