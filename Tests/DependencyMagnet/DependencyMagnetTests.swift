//
//  DependencyMagnetTests.swift
//  Copyright © 2025 Jason Fieldman.
//

@testable import DependencyMagnetLib
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
                config: "Dependencies/dependencies.yml",
                workspacePath: ".dependency_magnet",
                outputPath: "Dependencies"
            )
        )

        let result = Process.execute(
            command: "diff -r --exclude .DS_Store Setup Expectation",
            workingDirectory: URL(fileURLWithPath: testDirectory)
        )

        let diffStrings = result.stdout.split(separator: "\n")

        XCTAssert(diffStrings.count > 0)
        XCTAssert(diffStrings.count(where: { !$0.starts(with: "Only in") }) == 0)
    }
}
