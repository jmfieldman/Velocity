// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Velocity",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "dependency_magnet", targets: ["DependencyMagnet"]),
        .executable(name: "modules", targets: ["ModuleGeneration"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.12.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.3.0"),
        .package(url: "https://github.com/yonaskolb/XcodeGen.git", from: "2.42.0"),
    ],
    targets: [
        // Internal Utilities

        .target(
            name: "InternalUtilities",
            dependencies: [],
            path: "InternalUtilities"
        ),

        // Dependency Magnet

        .executableTarget(
            name: "DependencyMagnet",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "DependencyMagnetLib",
            ],
            path: "DependencyMagnet/Sources/Command"
        ),
        .target(
            name: "DependencyMagnetLib",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Yams", package: "Yams"),
                "InternalUtilities",
            ],
            path: "DependencyMagnet/Sources/Library"
        ),

        // Module Management

        .target(
            name: "ModuleManagementLib",
            dependencies: [
                .product(name: "ProjectSpec", package: "XcodeGen"),
                "InternalUtilities",
            ],
            path: "ModuleManagement/Sources/Library"
        ),

        // Module Generation

        .executableTarget(
            name: "ModuleGeneration",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ProjectSpec", package: "XcodeGen"),
                "InternalUtilities",
                "ModuleManagementLib",
                "ModuleGenerationLib",
                "DependencyMagnetLib",
            ],
            path: "ModuleGeneration/Sources/Command"
        ),
        .target(
            name: "ModuleGenerationLib",
            dependencies: [
                .product(name: "ProjectSpec", package: "XcodeGen"),
                "InternalUtilities",
                "ModuleManagementLib",
            ],
            path: "ModuleGeneration/Sources/Library"
        ),
    ]
)
