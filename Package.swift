// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Velocity",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "velocity", targets: ["Velocity"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.14.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.4.0"),
        .package(url: "https://github.com/yonaskolb/XcodeGen.git", from: "2.44.1"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.4"),
    ],
    targets: [
        // Internal Utilities

        .target(
            name: "InternalUtilities",
            dependencies: [],
            path: "Sources/Libraries/InternalUtilities"
        ),
        .target(
            name: "TestHelpers",
            dependencies: ["InternalUtilities"],
            path: "Tests/Helpers"
        ),

        // Velocity Command

        .executableTarget(
            name: "Velocity",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ProjectSpec", package: "XcodeGen"),
                "InternalUtilities",
                "ModuleManagementLib",
                "ModuleGenerationLib",
                "DependencyMagnetLib",
            ],
            path: "Sources/Command"
        ),

        // Libraries

        .target(
            name: "DependencyMagnetLib",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Yams", package: "Yams"),
                "InternalUtilities",
            ],
            path: "Sources/Libraries/DependencyMagnet"
        ),
        .target(
            name: "ModuleManagementLib",
            dependencies: [
                .product(name: "ProjectSpec", package: "XcodeGen"),
                "InternalUtilities",
            ],
            path: "Sources/Libraries/ModuleManagement"
        ),
        .target(
            name: "ModuleGenerationLib",
            dependencies: [
                .product(name: "ProjectSpec", package: "XcodeGen"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "SQLite", package: "SQLite.swift"),
                "InternalUtilities",
                "ModuleManagementLib",
                "DependencyMagnetLib",
            ],
            path: "Sources/Libraries/ModuleGeneration"
        ),

        // Tests

        .testTarget(
            name: "DependencyMagnetTests",
            dependencies: [
                "DependencyMagnetLib",
                "TestHelpers",
            ],
            path: "Tests/DependencyMagnet",
            resources: [.copy("Files")]
        ),
        .testTarget(
            name: "ModuleGenerationTests",
            dependencies: [
                .product(name: "ProjectSpec", package: "XcodeGen"),
                "InternalUtilities",
                "ModuleManagementLib",
                "ModuleGenerationLib",
                "DependencyMagnetLib",
                "TestHelpers",
            ],
            path: "Tests/ModuleGeneration",
            resources: [.copy("Files")]
        ),
    ]
)
