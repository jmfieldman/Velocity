//
//  GenerateXcodegenModulesCommandTests.swift
//  Copyright © 2025 Jason Fieldman.
//

import InternalUtilities
@testable import ModuleGenerationLib
import TestHelpers
import XCTest

final class GenerateXcodegenModulesCommandTests: XCTestCase {
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

        try GenerateXcodegenModules.execute(
            with: GenerateXcodegenModulesOptions(
                rootPath: "Modules",
                regenImports: false,
                outputFilename: "project-modules.yml",
                platforms: "iOS",
                dependenciesConfig: kPathDependencyConfig,
                packageFileName: kPathPackageYml
            )
        )

        TestHelpers.validateDiffResults(
            testDirectory: testDirectory,
            allowFilePathDifferences: true
        )
    }
}
