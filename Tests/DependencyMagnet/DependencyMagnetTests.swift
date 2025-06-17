//
//  DependencyMagnetTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import DependencyMagnetLib
import InternalUtilities
import TestHelpers
import XCTest

final class DependencyMagnetTests: XCTestCase {
    func testBasicDependenciesExecution() throws {
        guard let basePath = Bundle.module.path(forResource: "Files", ofType: "") else {
            XCTFail("No Files")
            return
        }

        let testDirectory = try TestHelpers.initializeTest(
            basePath: basePath,
            directory: "TestBasicDependenciesExecution"
        )

        TestHelpers.validateTestDirectoryAndSetCurrent(testDirectory)

        try DependencyPull().execute(
            with: DependencyPullOptions(
                config: kPathDependencyConfig,
                workspacePath: kPathMagnetWorkspace,
                outputPath: "Dependencies"
            )
        )

        TestHelpers.validateDiffResults(
            testDirectory: testDirectory,
            allowFilePathDifferences: true
        )
    }
}
