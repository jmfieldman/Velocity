//
//  ModuleGenerationTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import ModuleGenerationLib
import TestHelpers
import XCTest

final class ModuleGenerationTests: XCTestCase {
    /// Passing `nil` to `dependencyOutputPath` means that generation will force
    /// the use of all-remote dependencies (since it cannot specify the local repo
    /// path.)
    func testRemoteDependencies() throws {
        guard let basePath = Bundle.module.path(forResource: "Files", ofType: "") else {
            XCTFail("No Files")
            return
        }

        let testDirectory = try TestHelpers.initializeTest(
            basePath: basePath,
            directory: "TestRemoteDependencies"
        )

        TestHelpers.validateTestDirectoryAndSetCurrent(testDirectory)

        try GenerateXcodegenDeps.execute(
            with: GenerateXcodegenDepsOptions(
                outputFilename: "project-dependencies.yml",
                dependenciesConfig: "Dependencies/dependencies.yml",
                dependencyOutputPath: nil
            )
        )

        TestHelpers.validateDiffResults(
            testDirectory: testDirectory,
            allowFilePathDifferences: false
        )
    }
}
