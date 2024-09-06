// swift-tools-version:5.8

import PackageDescription

let package = Package(
  name: "SwiftDependencyMagnetTest",
  platforms: [.macOS(.v12)],
  products: [
    .executable(name: "dependency_magnet_test", targets: ["DependencyMagnetTest"]),
  ],
  dependencies: [
    .package(path: "Dependencies/Packages/swift-argument-parser"),
    .package(path: "Dependencies/Packages/swift-crypto"),
    .package(path: "Dependencies/Packages/Yams"),
    .package(path: "Dependencies/Packages/vapor"),
    .package(path: "Dependencies/Packages/redis"),
    .package(path: "Dependencies/Packages/fluent"),
  ],
  targets: [
    .executableTarget(
      name: "DependencyMagnetTest",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Yams", package: "Yams"),
        "DependencyMagnetTestLib",
      ],
      path: "Sources/DependencyMagnetTest"
    ),
    .target(
      name: "DependencyMagnetTestLib",
      dependencies: [
        .product(name: "Crypto", package: "swift-crypto"),
        .product(name: "Vapor", package: "vapor"),
        .product(name: "Redis", package: "redis"),
        .product(name: "Fluent", package: "fluent"),
      ],
      path: "Sources/DependencyMagnetTestLib"
    ),
  ]
)
