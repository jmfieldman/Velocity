//
//  GenerateImportsCommandTests.swift
//  Copyright © 2025 Jason Fieldman.
//

import Foundation
import InternalUtilities
@testable import ModuleGenerationLib
import TestHelpers
import XCTest

final class GenerateImportsCommandTests: XCTestCase {
    func testBasicModules() throws {
        guard let basePath = Bundle.module.path(forResource: "Files", ofType: "") else {
            XCTFail("No Files")
            return
        }

        let testDirectory = try TestHelpers.initializeTest(
            basePath: basePath,
            directory: "TestImportsBasic"
        )

        TestHelpers.validateTestDirectoryAndSetCurrent(testDirectory)

        try GenerateImports.execute(
            with: GenerateImportsOptions(
                searchPath: ".",
                projectPath: nil,
                packageFilename: kFilenamePackageYml
            )
        )

        TestHelpers.validateDiffResults(
            testDirectory: testDirectory,
            allowFilePathDifferences: false
        )
    }
}
