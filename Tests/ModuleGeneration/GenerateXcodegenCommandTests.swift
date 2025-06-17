//
//  GenerateXcodegenCommandTests.swift
//  Copyright © 2025 Jason Fieldman.
//

import InternalUtilities
@testable import ModuleGenerationLib
import TestHelpers
import XCTest

final class GenerateXcodegenCommandTests: XCTestCase {
    func testBasicModules() throws {
        guard let basePath = Bundle.module.path(forResource: "Files", ofType: "") else {
            XCTFail("No Files")
            return
        }

        let testDirectory = try TestHelpers.initializeTest(
            basePath: basePath,
            directory: "TestModulesBasic"
        )

        TestHelpers.validateTestDirectoryAndSetCurrent(testDirectory)

        try GenerateXcodegen.execute(
            with: GenerateXcodegenOptions(
                rootPath: "Modules",
                regenImports: false,
                outputFilename: "project-modules.yml",
                platforms: "iOS",
                dependenciesConfig: "Dependencies/dependencies.yml",
                packageFileName: kPathPackageYml
            )
        )

        TestHelpers.validateDiffResults(
            testDirectory: testDirectory,
            allowFilePathDifferences: true
        )
    }
}
