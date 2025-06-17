//
//  GenerateXcodegenDepsCommandTests.swift
//  Copyright © 2025 Jason Fieldman.
//

import InternalUtilities
@testable import ModuleGenerationLib
import TestHelpers
import XCTest

final class GenerateXcodegenDepsCommandTests: XCTestCase {
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
            directory: "TestDepsRemoteDependencies"
        )

        TestHelpers.validateTestDirectoryAndSetCurrent(testDirectory)

        try GenerateXcodegenDeps.execute(
            with: GenerateXcodegenDepsOptions(
                outputFilename: "project-dependencies.yml",
                dependenciesConfig: kPathDependencyConfig,
                dependencyOutputPath: nil
            )
        )

        TestHelpers.validateDiffResults(
            testDirectory: testDirectory,
            allowFilePathDifferences: false
        )
    }

    func testLocalDependencies() throws {
        guard let basePath = Bundle.module.path(forResource: "Files", ofType: "") else {
            XCTFail("No Files")
            return
        }

        let testDirectory = try TestHelpers.initializeTest(
            basePath: basePath,
            directory: "TestDepsLocalDependencies"
        )

        TestHelpers.validateTestDirectoryAndSetCurrent(testDirectory)

        try GenerateXcodegenDeps.execute(
            with: GenerateXcodegenDepsOptions(
                outputFilename: "project-dependencies.yml",
                dependenciesConfig: kPathDependencyConfig,
                dependencyOutputPath: "Dependencies"
            )
        )

        TestHelpers.validateDiffResults(
            testDirectory: testDirectory,
            allowFilePathDifferences: false
        )
    }
}
