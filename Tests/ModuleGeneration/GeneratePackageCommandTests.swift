//
//  GeneratePackageCommandTests.swift
//  Copyright © 2025 Jason Fieldman.
//

import Foundation
import InternalUtilities
@testable import ModuleGenerationLib
import TestHelpers
import XCTest

final class GeneratePackageCommandTests: XCTestCase {
    func testBasicPackage() throws {
        guard let basePath = Bundle.module.path(forResource: "Files", ofType: "") else {
            XCTFail("No Files")
            return
        }

        let testDirectory = try TestHelpers.initializeTest(
            basePath: basePath,
            directory: "TestPackageBasic"
        )

        TestHelpers.validateTestDirectoryAndSetCurrent(testDirectory)

        try GeneratePackage.execute(
            with: GeneratePackageOptions(
                regenImports: true,
                rootPath: ".",
                swiftToolsVersion: "5.9",
                platforms: "iOS",
                dependenciesConfig: kPathDependencyConfig,
                dependencyOutputPath: nil,
                packageName: "TestPackage",
                packageFileName: kPathPackageYml
            )
        )

        TestHelpers.validateDiffResults(
            testDirectory: testDirectory,
            allowFilePathDifferences: false
        )
    }
}
