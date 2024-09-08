// swift-tools-version:5.8

import PackageDescription

let package = Package(
  name: "Velocity",
  platforms: [.macOS(.v12)],
  products: [
    .executable(name: "dependency_magnet", targets: ["DependencyMagnet"]),
    .executable(name: "modules", targets: ["ModuleGeneration"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.5.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", exact: "3.7.0"),
    .package(url: "https://github.com/jpsim/Yams.git", exact: "5.1.3"),
    .package(url: "https://github.com/yonaskolb/XcodeGen.git", exact: "2.42.0"),
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
