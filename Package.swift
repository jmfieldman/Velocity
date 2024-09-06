// swift-tools-version:5.8

import PackageDescription

let package = Package(
  name: "Velocity",
  platforms: [.macOS(.v12)],
  products: [
    .executable(name: "dependency_magnet", targets: ["DependencyMagnet"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.4.0"),
    .package(url: "https://github.com/apple/swift-crypto.git", exact: "3.5.2"),
    .package(url: "https://github.com/jpsim/Yams.git", exact: "5.1.2"),
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
        .product(name: "Yams", package: "Yams"),
        "DependencyMagnetLib",
      ],
      path: "DependencyMagnet/Sources/Command"
    ),
    .target(
      name: "DependencyMagnetLib",
      dependencies: [
        .product(name: "Crypto", package: "swift-crypto"),
        "InternalUtilities",
      ],
      path: "DependencyMagnet/Sources/Library"
    ),
  ]
)
