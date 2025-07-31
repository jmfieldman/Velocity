//
//  GenerateInjectCommandTests.swift
//  Copyright © 2025 Jason Fieldman.
//

import InternalUtilities
@testable import ModuleGenerationLib
import TestHelpers
import XCTest

final class GenerateInjectCommandTests: XCTestCase {
    func testBasicModules() throws {
        guard let basePath = Bundle.module.path(forResource: "Files", ofType: "") else {
            XCTFail("No Files")
            return
        }

        let testDirectory = try TestHelpers.initializeTest(
            basePath: basePath,
            directory: "TestInjectBasic"
        )

        TestHelpers.validateTestDirectoryAndSetCurrent(testDirectory)

        try GenerateInject.execute(
            with: GenerateInjectOptions(
                modulesPath: "Modules",
                outputFile: "InjectModule/inject.swift",
                injectFunctionName: "injectImplementations",
                packageFileName: kPathPackageYml
            )
        )

        TestHelpers.validateDiffResults(
            testDirectory: testDirectory,
            allowFilePathDifferences: false
        )
    }
}
